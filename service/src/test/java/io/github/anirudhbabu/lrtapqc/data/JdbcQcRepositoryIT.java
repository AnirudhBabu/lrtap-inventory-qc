package io.github.anirudhbabu.lrtapqc.data;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.List;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

/**
 * The repository's SQL against a real Oracle schema with the project
 * installed (scripts/run_tests.sh provides one). Runs only when
 * LRTAP_JDBC_URL is set.
 *
 * The fixture is committed, because the repository opens its own
 * connections, and removed afterwards. It uses the country code XQ, from the
 * range ISO 3166 reserves for user-assigned codes, so it cannot collide with
 * a real Party. Pollutant NOX and sector 1A1a come from the installed
 * reference data.
 */
@EnabledIfEnvironmentVariable(named = "LRTAP_JDBC_URL", matches = ".+")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class JdbcQcRepositoryIT {

    private static final String COUNTRY = "XQ";
    private static final double SLOPE = Math.log10(0.9);

    private SimpleDataSource dataSource;
    private JdbcQcRepository repo;
    private long runId;

    @BeforeAll
    void insertFixture() throws SQLException {
        dataSource = SimpleDataSource.fromEnvironment(System.getenv());
        repo = new JdbcQcRepository(dataSource);
        try (Connection c = dataSource.getConnection()) {
            c.setAutoCommit(false);
            execute(c, "insert into ref_country (country_code, country_name, in_scope) values (?, 'Test area', 'Y')", COUNTRY);
            // NOX, 1A1a: 100 x 0.9^(year - 2010), with 2012 as a notation key.
            for (int year = 2010; year <= 2014; year++) {
                if (year == 2012) {
                    execute(c, "insert into emission (country_code, pollutant_code, sector_code, year, notation_key)"
                            + " values (?, 'NOX', '1A1a', ?, 'NE')", COUNTRY, year);
                } else {
                    execute(c, "insert into emission (country_code, pollutant_code, sector_code, year, value)"
                            + " values (?, 'NOX', '1A1a', ?, ?)", COUNTRY, year, 100 * Math.pow(0.9, year - 2010));
                }
            }
            try (PreparedStatement ps = c.prepareStatement(
                    "insert into qc_run (started_at, finished_at) values (systimestamp, systimestamp)",
                    new String[] {"RUN_ID"})) {
                ps.executeUpdate();
                try (ResultSet rs = ps.getGeneratedKeys()) {
                    rs.next();
                    runId = rs.getLong(1);
                }
            }
            String finding = "insert into qc_finding (run_id, check_id, country_code, pollutant_code, sector_code,"
                    + " year, observed, expected, detail) values (?, ?, ?, 'NOX', '1A1a', ?, ?, ?, ?)";
            execute(c, finding, runId, "QC07", COUNTRY, 2013, new BigDecimal("72.9"), new BigDecimal("70"), "test finding 2013");
            execute(c, finding, runId, "QC07", COUNTRY, 2011, new BigDecimal("90"), new BigDecimal("88"), "test finding 2011");
            execute(c, finding, runId, "QC03", COUNTRY, 2012, null, null, "Reported as NE");
            c.commit();
        }
    }

    @AfterAll
    void removeFixture() throws SQLException {
        try (Connection c = dataSource.getConnection()) {
            execute(c, "delete from qc_finding where run_id = ?", runId);
            execute(c, "delete from qc_run where run_id = ?", runId);
            execute(c, "delete from emission where country_code = ?", COUNTRY);
            execute(c, "delete from ref_country where country_code = ?", COUNTRY);
        }
    }

    /** Nulls are bound as NUMBER: in this fixture only numeric columns take null. */
    private static void execute(Connection c, String sql, Object... binds) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            for (int i = 0; i < binds.length; i++) {
                if (binds[i] == null) {
                    ps.setNull(i + 1, Types.NUMERIC);
                } else {
                    ps.setObject(i + 1, binds[i]);
                }
            }
            ps.executeUpdate();
        }
    }

    @Test
    void listsTheRunWithItsFindingCount() {
        Run run = repo.runs().stream().filter(r -> r.runId() == runId).findFirst().orElseThrow();
        assertEquals(3, run.findings());
        assertTrue(repo.runExists(runId));
        assertTrue(repo.latestRunId().orElseThrow() >= runId);
    }

    @Test
    void summarisesByCheckAndCountry() {
        List<SummaryRow> rows = repo.summary(runId);
        assertEquals(List.of(
                new SummaryRow("QC03", "Emissions reported as Not Estimated", "WARNING", COUNTRY, 1),
                new SummaryRow("QC07", "Time-series dip or jump", "WARNING", COUNTRY, 2)), rows);
    }

    @Test
    void filtersAndPagesFindings() {
        FindingFilter qc07 = new FindingFilter("QC07", COUNTRY, null, null, null);
        Page<Finding> all = repo.findings(runId, qc07, 100, 0);
        assertEquals(2, all.total());
        assertEquals(List.of(2011, 2013), all.items().stream().map(Finding::year).toList());

        Page<Finding> second = repo.findings(runId, qc07, 1, 1);
        assertEquals(2, second.total());
        assertEquals(2013, second.items().get(0).year());
        assertEquals(new BigDecimal("72.9"), second.items().get(0).observed());

        Page<Finding> oneYear = repo.findings(runId, new FindingFilter(null, COUNTRY, null, null, 2012), 100, 0);
        assertEquals(1, oneYear.total());
        assertNull(oneYear.items().get(0).observed());
    }

    @Test
    void seriesHasEveryYearTheTrendAndTheChecks() {
        Series s = repo.series(runId, COUNTRY, "NOX", "1A1a").orElseThrow();
        assertEquals("kt", s.unit());
        assertEquals(List.of(2010, 2011, 2012, 2013, 2014), s.points().stream().map(SeriesPoint::year).toList());

        SeriesPoint ne = s.points().get(2);
        assertNull(ne.value());
        assertEquals("NE", ne.notationKey());
        assertEquals(List.of("QC03"), ne.checks());
        assertEquals(List.of("QC07"), s.points().get(1).checks());
        assertEquals(List.of(), s.points().get(0).checks());

        // Fitted by the qc07_trend view on the four positive values.
        assertEquals(4, s.trend().years());
        assertEquals(SLOPE, s.trend().slope(), 1e-9);
        assertEquals(100.0, s.trend().valueAt(2010), 1e-6);
    }

    @Test
    void unknownSeriesIsEmpty() {
        assertTrue(repo.series(runId, COUNTRY, "NOX", "1A1b").isEmpty());
    }
}
