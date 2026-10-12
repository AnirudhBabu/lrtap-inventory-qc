package io.github.anirudhbabu.lrtapqc.api;

import java.util.Map;

/**
 * Reads query parameters, and rejects bad ones with a message that says what
 * was expected. Text is trimmed, and blank counts as absent. When a parameter
 * is repeated, its first value is used.
 */
public final class Params {

    /** No code in the data is longer; anything longer is a mistake. */
    static final int MAX_TEXT = 100;

    private final Map<String, String[]> values;

    public Params(Map<String, String[]> values) {
        this.values = values;
    }

    public String optionalText(String name) {
        String[] given = values.get(name);
        if (given == null || given.length == 0 || given[0] == null || given[0].isBlank()) {
            return null;
        }
        String text = given[0].trim();
        if (text.length() > MAX_TEXT) {
            throw ApiException.badRequest("parameter " + name + " is longer than " + MAX_TEXT + " characters");
        }
        return text;
    }

    public String requiredText(String name) {
        String text = optionalText(name);
        if (text == null) {
            throw ApiException.badRequest("missing parameter: " + name);
        }
        return text;
    }

    /** A whole number from min to max, or the default when absent. */
    public int optionalInt(String name, int min, int max, int defaultValue) {
        Integer value = optionalInteger(name, min, max);
        return value == null ? defaultValue : value;
    }

    /** A whole number from min to max, or null when absent. */
    public Integer optionalInteger(String name, int min, int max) {
        String text = optionalText(name);
        if (text == null) {
            return null;
        }
        try {
            int value = Integer.parseInt(text);
            if (value >= min && value <= max) {
                return value;
            }
        } catch (NumberFormatException e) {
            // reported below
        }
        throw ApiException.badRequest("parameter " + name + " must be a whole number from " + min + " to " + max);
    }
}
