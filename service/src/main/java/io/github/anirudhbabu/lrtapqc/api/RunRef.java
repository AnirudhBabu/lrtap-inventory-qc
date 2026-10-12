package io.github.anirudhbabu.lrtapqc.api;

/** A run named in a request: a run id, or null for the latest run. */
public record RunRef(Long id) {

    public static final String LATEST = "latest";

    public static RunRef parse(String text) {
        if (LATEST.equals(text)) {
            return new RunRef(null);
        }
        try {
            long id = Long.parseLong(text);
            if (id > 0) {
                return new RunRef(id);
            }
        } catch (NumberFormatException e) {
            // reported below
        }
        throw ApiException.badRequest("run must be a positive whole number or '" + LATEST + "'");
    }
}
