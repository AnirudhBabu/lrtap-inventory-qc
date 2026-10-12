package io.github.anirudhbabu.lrtapqc.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;

class JsonWriterTest {

    @Test
    void writesNestedObjectsAndArrays() {
        String json = new JsonWriter()
                .beginObject()
                .name("runId").value(3L)
                .name("rows").beginArray()
                    .beginObject().name("checkId").value("QC05").name("findings").value(121L).endObject()
                    .beginObject().name("checkId").value("QC06").name("findings").value(3138L).endObject()
                .endArray()
                .endObject()
                .toString();
        assertEquals("{\"runId\":3,\"rows\":[{\"checkId\":\"QC05\",\"findings\":121},"
                + "{\"checkId\":\"QC06\",\"findings\":3138}]}", json);
    }

    @Test
    void writesNullAndBooleans() {
        String json = new JsonWriter().beginObject()
                .name("a").nullValue()
                .name("b").value(true)
                .name("c").value((String) null)
                .name("d").value((BigDecimal) null)
                .endObject().toString();
        assertEquals("{\"a\":null,\"b\":true,\"c\":null,\"d\":null}", json);
    }

    @Test
    void escapesStrings() {
        String json = new JsonWriter().value("quote \" backslash \\ newline \n tab \t bell \u0007").toString();
        assertEquals("\"quote \\\" backslash \\\\ newline \\n tab \\t bell \\u0007\"", json);
    }

    @Test
    void keepsNonAsciiTextAsIs() {
        // The response is UTF-8, so country names such as Türkiye need no escaping.
        assertEquals("\"Türkiye\"", new JsonWriter().value("Türkiye").toString());
    }

    @Test
    void writesDecimalsExactly() {
        // Oracle NUMBER values arrive as BigDecimal; their digits must survive.
        String json = new JsonWriter().beginArray()
                .value(new BigDecimal("5460.81"))
                .value(new BigDecimal("0.000123456789012345678"))
                .value(new BigDecimal("-2"))
                .endArray().toString();
        assertEquals("[5460.81,0.000123456789012345678,-2]", json);
    }

    @Test
    void writesDoubles() {
        assertEquals("[2364.054332252161,1.0E-5]",
                new JsonWriter().beginArray().value(2364.054332252161).value(1e-5).endArray().toString());
    }

    @Test
    void refusesNumbersJsonCannotRepresent() {
        assertThrows(IllegalArgumentException.class, () -> new JsonWriter().value(Double.NaN));
        assertThrows(IllegalArgumentException.class, () -> new JsonWriter().value(Double.POSITIVE_INFINITY));
    }

    @Test
    void writesListsOfStrings() {
        assertEquals("[\"QC06\",\"QC07\"]", new JsonWriter().stringArray(List.of("QC06", "QC07")).toString());
    }
}
