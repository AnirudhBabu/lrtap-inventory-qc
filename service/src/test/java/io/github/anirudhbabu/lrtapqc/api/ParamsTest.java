package io.github.anirudhbabu.lrtapqc.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.Map;
import org.junit.jupiter.api.Test;

class ParamsTest {

    private static Params params(String... nameValuePairs) {
        java.util.Map<String, String[]> map = new java.util.HashMap<>();
        for (int i = 0; i < nameValuePairs.length; i += 2) {
            map.put(nameValuePairs[i], new String[] {nameValuePairs[i + 1]});
        }
        return new Params(map);
    }

    @Test
    void optionalTextIsTrimmedAndBlankMeansAbsent() {
        Params p = params("country", "  LV ", "check", "   ");
        assertEquals("LV", p.optionalText("country"));
        assertNull(p.optionalText("check"));
        assertNull(p.optionalText("pollutant"));
    }

    @Test
    void requiredTextMustBePresent() {
        ApiException e = assertThrows(ApiException.class, () -> params().requiredText("sector"));
        assertEquals(400, e.status());
        assertEquals("missing parameter: sector", e.getMessage());
    }

    @Test
    void textLongerThanAnyCodeIsRejected() {
        ApiException e = assertThrows(ApiException.class,
                () -> params("sector", "x".repeat(101)).optionalText("sector"));
        assertEquals(400, e.status());
        assertEquals("parameter sector is longer than 100 characters", e.getMessage());
    }

    @Test
    void optionalIntUsesDefaultWhenAbsent() {
        assertEquals(100, params().optionalInt("limit", 1, 1000, 100));
    }

    @Test
    void optionalIntParsesWithinBounds() {
        assertEquals(1000, params("limit", "1000").optionalInt("limit", 1, 1000, 100));
    }

    @Test
    void optionalIntRejectsOutOfRangeAndNonNumbers() {
        for (String bad : new String[] {"0", "1001", "ten", "1.5", "-3"}) {
            ApiException e = assertThrows(ApiException.class,
                    () -> params("limit", bad).optionalInt("limit", 1, 1000, 100), bad);
            assertEquals(400, e.status());
            assertEquals("parameter limit must be a whole number from 1 to 1000", e.getMessage());
        }
    }

    @Test
    void optionalYearIsNullWhenAbsent() {
        assertNull(params().optionalInteger("year", 1900, 2100));
        assertEquals(1990, params("year", "1990").optionalInteger("year", 1900, 2100));
    }

    @Test
    void usesTheFirstValueOfARepeatedParameter() {
        Params p = new Params(Map.of("country", new String[] {"DE", "FR"}));
        assertEquals("DE", p.optionalText("country"));
    }
}
