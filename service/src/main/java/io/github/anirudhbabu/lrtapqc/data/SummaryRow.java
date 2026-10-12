package io.github.anirudhbabu.lrtapqc.data;

/** How many findings one check reported for one country in a run. */
public record SummaryRow(String checkId, String title, String severity, String countryCode, long findings) {
}
