package io.github.anirudhbabu.lrtapqc.data;

import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.SQLFeatureNotSupportedException;
import java.util.Map;
import java.util.logging.Logger;
import javax.sql.DataSource;

/**
 * Opens a new JDBC connection for each request, with settings from the
 * environment:
 *
 *   LRTAP_JDBC_URL       e.g. jdbc:oracle:thin:@//localhost:1521/FREEPDB1
 *   LRTAP_JDBC_USER
 *   LRTAP_JDBC_PASSWORD
 *
 * There is no pool. The API answers a reviewer's occasional questions, and a
 * connection per request keeps it simple; a pool (such as a Tomcat JNDI
 * DataSource) can replace this class without other changes.
 */
public final class SimpleDataSource implements DataSource {

    public static final String URL = "LRTAP_JDBC_URL";
    public static final String USER = "LRTAP_JDBC_USER";
    public static final String PASSWORD = "LRTAP_JDBC_PASSWORD";

    private final String url;
    private final String user;
    private final String password;

    public SimpleDataSource(String url, String user, String password) {
        this.url = url;
        this.user = user;
        this.password = password;
    }

    /** Fails with the name of the first missing variable. */
    public static SimpleDataSource fromEnvironment(Map<String, String> env) {
        return new SimpleDataSource(required(env, URL), required(env, USER), required(env, PASSWORD));
    }

    private static String required(Map<String, String> env, String name) {
        String value = env.get(name);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("environment variable " + name + " is not set");
        }
        return value;
    }

    @Override
    public Connection getConnection() throws SQLException {
        return DriverManager.getConnection(url, user, password);
    }

    @Override
    public Connection getConnection(String otherUser, String otherPassword) throws SQLException {
        return DriverManager.getConnection(url, otherUser, otherPassword);
    }

    @Override
    public PrintWriter getLogWriter() {
        return DriverManager.getLogWriter();
    }

    @Override
    public void setLogWriter(PrintWriter out) {
        DriverManager.setLogWriter(out);
    }

    @Override
    public void setLoginTimeout(int seconds) {
        DriverManager.setLoginTimeout(seconds);
    }

    @Override
    public int getLoginTimeout() {
        return DriverManager.getLoginTimeout();
    }

    @Override
    public Logger getParentLogger() throws SQLFeatureNotSupportedException {
        throw new SQLFeatureNotSupportedException();
    }

    @Override
    public <T> T unwrap(Class<T> iface) throws SQLException {
        if (iface.isInstance(this)) {
            return iface.cast(this);
        }
        throw new SQLException("not a wrapper for " + iface.getName());
    }

    @Override
    public boolean isWrapperFor(Class<?> iface) {
        return iface.isInstance(this);
    }
}
