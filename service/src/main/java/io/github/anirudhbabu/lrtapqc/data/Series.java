package io.github.anirudhbabu.lrtapqc.data;

import java.util.List;

/** A country's reported values for one pollutant and sector, year by year. trend may be null. */
public record Series(
        String countryCode,
        String pollutantCode,
        String sectorCode,
        String unit,
        Trend trend,
        List<SeriesPoint> points) {
}
