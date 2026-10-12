package io.github.anirudhbabu.lrtapqc.data;

/** Optional conditions on findings; a null field means "any". */
public record FindingFilter(
        String checkId,
        String countryCode,
        String pollutantCode,
        String sectorCode,
        Integer year) {
}
