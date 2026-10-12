package io.github.anirudhbabu.lrtapqc.api;

import java.math.BigDecimal;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;

/**
 * Writes JSON text, with commas placed automatically. Small on purpose: the
 * API only writes JSON, never reads it, so a full library would add a
 * dependency for little gain.
 *
 *   new JsonWriter().beginObject().name("runId").value(3L).endObject()   ->   {"runId":3}
 */
public final class JsonWriter {

    private final StringBuilder out = new StringBuilder();
    /** One entry per open object or array: true until its first element is written. */
    private final Deque<Boolean> first = new ArrayDeque<>();
    private boolean afterName;

    /** Writes the comma, if one is due, before the next element. */
    private void beforeElement() {
        if (afterName) {
            afterName = false;
            return;
        }
        if (!first.isEmpty()) {
            if (!first.pop()) {
                out.append(',');
            }
            first.push(false);
        }
    }

    public JsonWriter beginObject() {
        beforeElement();
        out.append('{');
        first.push(true);
        return this;
    }

    public JsonWriter endObject() {
        first.pop();
        out.append('}');
        return this;
    }

    public JsonWriter beginArray() {
        beforeElement();
        out.append('[');
        first.push(true);
        return this;
    }

    public JsonWriter endArray() {
        first.pop();
        out.append(']');
        return this;
    }

    public JsonWriter name(String name) {
        beforeElement();
        writeString(name);
        out.append(':');
        afterName = true;
        return this;
    }

    public JsonWriter value(String value) {
        beforeElement();
        if (value == null) {
            out.append("null");
        } else {
            writeString(value);
        }
        return this;
    }

    public JsonWriter value(long value) {
        beforeElement();
        out.append(value);
        return this;
    }

    /** Doubles that are not numbers (NaN, infinities) have no JSON form. */
    public JsonWriter value(double value) {
        if (Double.isNaN(value) || Double.isInfinite(value)) {
            throw new IllegalArgumentException("JSON cannot represent " + value);
        }
        beforeElement();
        out.append(value);
        return this;
    }

    /** Exact decimal digits, as Oracle NUMBER stores them. */
    public JsonWriter value(BigDecimal value) {
        beforeElement();
        out.append(value == null ? "null" : value.toString());
        return this;
    }

    public JsonWriter value(boolean value) {
        beforeElement();
        out.append(value);
        return this;
    }

    public JsonWriter nullValue() {
        beforeElement();
        out.append("null");
        return this;
    }

    public JsonWriter stringArray(List<String> values) {
        beginArray();
        for (String v : values) {
            value(v);
        }
        return endArray();
    }

    private void writeString(String s) {
        out.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> out.append("\\\"");
                case '\\' -> out.append("\\\\");
                case '\b' -> out.append("\\b");
                case '\f' -> out.append("\\f");
                case '\n' -> out.append("\\n");
                case '\r' -> out.append("\\r");
                case '\t' -> out.append("\\t");
                default -> {
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
                }
            }
        }
        out.append('"');
    }

    @Override
    public String toString() {
        return out.toString();
    }
}
