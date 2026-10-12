package io.github.anirudhbabu.lrtapqc.data;

/**
 * The line QC07 fits to a series: log10(value) = intercept + slope * year,
 * from the qc07_trend view. years is how many values it was fitted to.
 */
public record Trend(double intercept, double slope, int years) {

    public double valueAt(int year) {
        return Math.pow(10, intercept + slope * year);
    }
}
