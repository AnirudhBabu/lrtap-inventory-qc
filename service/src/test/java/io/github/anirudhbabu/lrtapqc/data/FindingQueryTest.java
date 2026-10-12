package io.github.anirudhbabu.lrtapqc.data;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

class FindingQueryTest {

    private static final FindingFilter NONE = new FindingFilter(null, null, null, null, null);

    @Test
    void withoutFiltersOnlyTheRunIsBound() {
        FindingQuery q = FindingQuery.of(7, NONE, 100, 0);
        assertEquals("select count(*) from qc_finding where run_id = ?", q.countSql());
        assertEquals(List.of(7L), q.countBinds());
    }

    @Test
    void eachGivenFilterAddsOneCondition() {
        FindingQuery q = FindingQuery.of(7, new FindingFilter(null, "LV", "PM10", null, 2024), 100, 0);
        assertEquals("select count(*) from qc_finding where run_id = ?"
                + " and country_code = ? and pollutant_code = ? and year = ?", q.countSql());
        assertEquals(List.of(7L, "LV", "PM10", 2024), q.countBinds());
    }

    @Test
    void pageQueryOrdersAndPagesAfterTheSameConditions() {
        FindingQuery q = FindingQuery.of(7, new FindingFilter("QC05", null, null, null, null), 50, 100);
        assertEquals("select check_id, country_code, pollutant_code, sector_code, year,"
                + " observed, expected, detail from qc_finding where run_id = ? and check_id = ?"
                + " order by check_id, country_code, pollutant_code, sector_code, year, detail"
                + " offset ? rows fetch next ? rows only", q.pageSql());
        assertEquals(List.of(7L, "QC05", 100, 50), q.pageBinds());
    }

    @Test
    void valuesAreBoundNeverWrittenIntoTheSql() {
        String hostile = "LV' or '1'='1";
        FindingQuery q = FindingQuery.of(7, new FindingFilter(null, hostile, null, null, null), 100, 0);
        assertFalse(q.pageSql().contains(hostile));
        assertTrue(q.pageBinds().contains(hostile));
    }
}
