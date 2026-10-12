package io.github.anirudhbabu.lrtapqc.data;

/** A database error, unchecked so callers need not handle what they cannot fix. */
public class DataAccessException extends RuntimeException {

    private static final long serialVersionUID = 1L;

    public DataAccessException(String message, Throwable cause) {
        super(message, cause);
    }
}
