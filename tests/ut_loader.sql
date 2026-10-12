create or replace package ut_loader as
    --%suite(Loader: staging to emission)

    --%beforeeach
    procedure setup;

    --%test(A number is loaded as a value, with the pollutant name mapped to its code)
    procedure number_loaded_as_value;

    --%test(Numbers in scientific notation are read correctly)
    procedure scientific_notation_read;

    --%test(A notation key is loaded as a key, whichever column it arrives in)
    procedure key_loaded_from_either_column;

    --%test(Notation keys are trimmed and upper-cased)
    procedure key_trimmed_and_upper_cased;

    --%test(Sector codes are trimmed, as some arrive with a trailing space)
    procedure sector_code_trimmed;

    --%test(Known but out-of-scope areas and pollutants are not loaded, with the reason)
    procedure out_of_scope_not_loaded;

    --%test(Rows that cannot be interpreted are rejected with a reason)
    procedure uninterpretable_rows_rejected;

    --%test(Every copy of a duplicated cell is rejected)
    procedure duplicates_rejected;

    --%test(Loading again replaces the previous load)
    procedure reload_replaces;
end ut_loader;
/

create or replace package body ut_loader as

    procedure setup is
    begin
        ut_fixture.reset;
        ut_fixture.add_country('XA');
        ut_fixture.add_pollutant('NOX', 1990, p_source_name => 'NOx');
        ut_fixture.add_sector('S1');
    end setup;

    procedure stage(
        p_country in varchar2, p_pollutant in varchar2, p_sector in varchar2,
        p_year in varchar2, p_value in varchar2, p_notation in varchar2)
    is
    begin
        insert into stg_emission (country_code, pollutant_name, sector_code, year_text, value_text, notation_text)
        values (p_country, p_pollutant, p_sector, p_year, p_value, p_notation);
    end stage;

    function reason_for(p_year in varchar2) return varchar2 is
        l_reason load_reject.reason%type;
    begin
        select r.reason into l_reason
          from load_reject r join stg_emission s on s.stg_row_id = r.stg_row_id
         where s.year_text = p_year;
        return l_reason;
    end reason_for;

    procedure number_loaded_as_value is
        l_row emission%rowtype;
    begin
        stage('XA', 'NOx', 'S1', '2023', '1.25', null);
        inventory_loader.load;

        select * into l_row from emission;
        ut.expect(l_row.pollutant_code).to_equal('NOX');
        ut.expect(l_row.year).to_equal(2023);
        ut.expect(l_row.value).to_equal(1.25);
        ut.expect(l_row.notation_key).to_be_null();
    end number_loaded_as_value;

    procedure scientific_notation_read is
        l_value number;
    begin
        stage('XA', 'NOx', 'S1', '2023', '1.5E-3', null);
        inventory_loader.load;

        select value into l_value from emission;
        ut.expect(l_value).to_equal(0.0015);
    end scientific_notation_read;

    procedure key_loaded_from_either_column is
        n number;
    begin
        stage('XA', 'NOx', 'S1', '2022', null, 'NE');
        stage('XA', 'NOx', 'S1', '2023', 'NO', null);
        inventory_loader.load;

        select count(*) into n from emission
         where (year = 2022 and notation_key = 'NE')
            or (year = 2023 and notation_key = 'NO');
        ut.expect(n).to_equal(2);
    end key_loaded_from_either_column;

    procedure key_trimmed_and_upper_cased is
        l_key emission.notation_key%type;
    begin
        -- The 2026 EEA file has a few 'iE' cells.
        stage('XA', 'NOx', 'S1', '2023', null, ' iE ');
        inventory_loader.load;

        select notation_key into l_key from emission;
        ut.expect(l_key).to_equal('IE');
    end key_trimmed_and_upper_cased;

    procedure sector_code_trimmed is
        l_sector emission.sector_code%type;
    begin
        stage('XA', 'NOx', 'S1 ', '2023', '1.0', null);
        inventory_loader.load;

        select sector_code into l_sector from emission;
        ut.expect(l_sector).to_equal('S1');
    end sector_code_trimmed;

    procedure out_of_scope_not_loaded is
    begin
        ut_fixture.add_country('XZ', p_in_scope => 'N', p_note => 'aggregate of other areas');
        ut_fixture.add_pollutant('FUEL', null, p_source_name => 'Liquid Fuels',
                                 p_in_scope => 'N', p_note => 'activity data, not an emission');
        stage('XZ', 'NOx',          'S1', '2001', '1.0', null);
        stage('XA', 'Liquid Fuels', 'S1', '2002', '1.0', null);
        inventory_loader.load;

        ut.expect(reason_for('2001')).to_equal('out of scope: aggregate of other areas');
        ut.expect(reason_for('2002')).to_equal('out of scope: activity data, not an emission');
    end out_of_scope_not_loaded;

    -- Each row is told apart by its year text, so the expected reason can be
    -- read back for each one.
    procedure uninterpretable_rows_rejected is
        n number;
    begin
        stage('XA', 'NOx',   'S1', '2001', null,  null);   -- nothing in the cell
        stage('XA', 'NOx',   'S1', '2002', '1.0', 'NE');   -- two answers
        stage('XA', 'NOx',   'S1', '2003', 'XX',  null);   -- unknown text
        stage('XA', 'SO2??', 'S1', '2004', '1.0', null);   -- unknown pollutant
        stage('XA', 'NOx',   'ZZ', '2005', '1.0', null);   -- unknown sector
        stage('XA', 'NOx',   'S1', '20x6', '1.0', null);   -- not a year
        stage('XA', 'NOx',   'S1', '2007.5', '1.0', null); -- not a whole year
        stage('QQ', 'NOx',   'S1', '2008', '1.0', null);   -- unknown country
        inventory_loader.load;

        ut.expect(reason_for('2001')).to_equal('empty cell');
        ut.expect(reason_for('2002')).to_equal('both a value and a notation key');
        ut.expect(reason_for('2003')).to_equal('neither a number nor a notation key');
        ut.expect(reason_for('2004')).to_equal('unknown pollutant');
        ut.expect(reason_for('2005')).to_equal('unknown sector');
        ut.expect(reason_for('20x6')).to_equal('year is not a whole number between 1900 and 2100');
        ut.expect(reason_for('2007.5')).to_equal('year is not a whole number between 1900 and 2100');
        ut.expect(reason_for('2008')).to_equal('unknown country');

        select count(*) into n from emission;
        ut.expect(n).to_equal(0);
    end uninterpretable_rows_rejected;

    procedure duplicates_rejected is
        n_loaded number;
        n_rejected number;
    begin
        stage('XA', 'NOx', 'S1', '2023', '1.0', null);
        stage('XA', 'NOx', 'S1', '2023', '2.0', null);
        stage('XA', 'NOx', 'S1', '2022', '1.0', null);
        inventory_loader.load;

        select count(*) into n_loaded from emission;
        select count(*) into n_rejected from load_reject where reason = 'duplicate cell';
        ut.expect(n_loaded).to_equal(1);
        ut.expect(n_rejected).to_equal(2);
    end duplicates_rejected;

    procedure reload_replaces is
        n number;
    begin
        stage('XA', 'NOx', 'S1', '2023', '1.0', null);
        stage('XA', 'NOx', 'S1', '2001', null,  null);
        inventory_loader.load;
        inventory_loader.load;

        select count(*) into n from emission;
        ut.expect(n).to_equal(1);
        select count(*) into n from load_reject;
        ut.expect(n).to_equal(1);
    end reload_replaces;

end ut_loader;
/
