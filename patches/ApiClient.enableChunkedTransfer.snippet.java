    private static volatile boolean chunkedTransfer = false;

    /**
     * Enable chunked transfer encoding for multipart uploads (file parameters).
     *
     * When enabled, multipart request bodies are streamed using chunked
     * transfer encoding (no Content-Length header). When disabled (the default),
     * bodies are buffered to a byte array so a known Content-Length is sent.
     *
     * @return this ApiClient instance for method chaining
     */
    public ApiClient enableChunkedTransfer() {
        chunkedTransfer = true;
        // Force HTTP/1.1 so the JDK sends Transfer-Encoding: chunked when
        // the body publisher reports contentLength == -1.  HTTP/2 has its own
        // framing and does not use chunked transfer encoding.
        this.builder.version(java.net.http.HttpClient.Version.HTTP_1_1);
        return this;
    }

    /**
     * Check whether chunked transfer encoding is enabled.
     *
     * @return true if chunked transfer is enabled
     */
    public static boolean isChunkedTransferEnabled() {
        return chunkedTransfer;
    }
