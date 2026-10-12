package io.github.anirudhbabu.lrtapqc.data;

import java.math.BigDecimal;

/**
 * One row of qc_finding. observed and expected are null for checks that do
 * not compare two numbers. They stay BigDecimal so Oracle NUMBER values keep
 * every digit.
 */
public record Finding(
        String checkId,
        String countryCode,
        String pollutantCode,
        String sectorCode,
        int year,
        BigDecimal observed,
        BigDecimal expected,
        String detail) {
}
