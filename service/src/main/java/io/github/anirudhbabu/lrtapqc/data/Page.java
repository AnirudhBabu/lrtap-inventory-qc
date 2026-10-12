package io.github.anirudhbabu.lrtapqc.data;

import java.util.List;

/** Some of the matching items, and how many match in all. */
public record Page<T>(long total, List<T> items) {
}
