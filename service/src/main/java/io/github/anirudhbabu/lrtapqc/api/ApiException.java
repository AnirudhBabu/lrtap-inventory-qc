package io.github.anirudhbabu.lrtapqc.api;

/** A request the API cannot answer, with the HTTP status and a message for the caller. */
public class ApiException extends RuntimeException {

    private static final long serialVersionUID = 1L;

    private final int status;

    public ApiException(int status, String message) {
        super(message);
        this.status = status;
    }

    public static ApiException badRequest(String message) {
        return new ApiException(400, message);
    }

    public static ApiException notFound(String message) {
        return new ApiException(404, message);
    }

    public int status() {
        return status;
    }
}
