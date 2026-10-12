package io.github.anirudhbabu.lrtapqc.data;

import java.util.ArrayList;
import java.util.List;

/**
 * The SQL for one page of findings, and the values to bind to it.
 *
 * Each filter that is set adds one "column = ?" condition. Values are only
 * ever bound, never written into the SQL text, so a filter value cannot
 * change the statement.
 */
public final class FindingQuery {

    private static final String COLUMNS = "check_id, country_code, pollutant_code, sector_code, year,"
            + " observed, expected, detail";
    private static final String ORDER = " order by check_id, country_code, pollutant_code, sector_code, year, detail";

    private final String where;
    private final List<Object> whereBinds;
    private final int limit;
    private final int offset;

    private FindingQuery(String where, List<Object> whereBinds, int limit, int offset) {
        this.where = where;
        this.whereBinds = whereBinds;
        this.limit = limit;
        this.offset = offset;
    }

    public static FindingQuery of(long runId, FindingFilter filter, int limit, int offset) {
        StringBuilder where = new StringBuilder(" where run_id = ?");
        List<Object> binds = new ArrayList<>();
        binds.add(runId);
        addCondition(where, binds, "check_id", filter.checkId());
        addCondition(where, binds, "country_code", filter.countryCode());
        addCondition(where, binds, "pollutant_code", filter.pollutantCode());
        addCondition(where, binds, "sector_code", filter.sectorCode());
        addCondition(where, binds, "year", filter.year());
        return new FindingQuery(where.toString(), List.copyOf(binds), limit, offset);
    }

    private static void addCondition(StringBuilder where, List<Object> binds, String column, Object value) {
        if (value != null) {
            where.append(" and ").append(column).append(" = ?");
            binds.add(value);
        }
    }

    public String countSql() {
        return "select count(*) from qc_finding" + where;
    }

    public List<Object> countBinds() {
        return whereBinds;
    }

    /** Oracle 12c and later: OFFSET ... ROWS FETCH NEXT ... ROWS ONLY. */
    public String pageSql() {
        return "select " + COLUMNS + " from qc_finding" + where + ORDER + " offset ? rows fetch next ? rows only";
    }

    public List<Object> pageBinds() {
        List<Object> binds = new ArrayList<>(whereBinds);
        binds.add(offset);
        binds.add(limit);
        return List.copyOf(binds);
    }
}
