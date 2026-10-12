package io.github.anirudhbabu.lrtapqc.data;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

/** The QC07 trend line: log10(value) = intercept + slope * year. */
class TrendTest {

    // 100 x 0.9^(year - 2010): a 10 % fall a year, a straight line after log10.
    private static final double SLOPE = Math.log10(0.9);
    private static final Trend TREND = new Trend(2 - 2010 * SLOPE, SLOPE, 10);

    @Test
    void reproducesTheSeriesItWasFittedTo() {
        assertEquals(100.0, TREND.valueAt(2010), 1e-9);
        assertEquals(90.0, TREND.valueAt(2011), 1e-9);
        assertEquals(100 * Math.pow(0.9, 9), TREND.valueAt(2019), 1e-9);
    }

    @Test
    void extendsBeyondTheFittedYears() {
        assertEquals(100 / 0.9, TREND.valueAt(2009), 1e-9);
    }
}
