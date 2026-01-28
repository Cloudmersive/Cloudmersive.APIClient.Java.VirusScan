    /**
     * Enable chunked transfer encoding for multipart uploads (file parameters).
     *
     * This configures the underlying OkHttpClient to:
     *  - use HTTP/1.1 (so Transfer-Encoding: chunked applies), and
     *  - wrap multipart request bodies so the content length is unknown.
     *
     * Calling this method multiple times will not add duplicate interceptors.
     *
     * @return ApiClient
     */
    public ApiClient enableChunkedTransfer() {
        OkHttpClient base = getHttpClient();

        // Don't add the interceptor more than once.
        for (Interceptor i : base.interceptors()) {
            if (i instanceof ForceChunkedMultipartInterceptor) {
                return this;
            }
        }

        OkHttpClient chunked = base.newBuilder()
                .protocols(Collections.singletonList(Protocol.HTTP_1_1))
                .addInterceptor(new ForceChunkedMultipartInterceptor())
                .build();

        return setHttpClient(chunked);
    }
