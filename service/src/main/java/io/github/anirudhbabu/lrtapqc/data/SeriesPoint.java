package io.github.anirudhbabu.lrtapqc.data;

import java.math.BigDecimal;
import java.util.List;

/**
 * One year of a series: a value or a notation key (or neither, for a year
 * that is missing), and the checks that reported a finding for it.
 */
public record SeriesPoint(int year, BigDecimal value, String notationKey, List<String> checks) {
}
