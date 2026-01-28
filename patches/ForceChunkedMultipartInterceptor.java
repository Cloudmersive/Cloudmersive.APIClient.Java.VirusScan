package org.openapitools.client;

import okhttp3.Interceptor;
import okhttp3.MediaType;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okio.BufferedSink;

import java.io.IOException;

/**
 * OkHttp interceptor that forces multipart request bodies to have unknown content length,
 * causing HTTP/1.1 requests to be sent using chunked transfer encoding.
 *
 * Note: HTTP/2 does not use Transfer-Encoding: chunked.
 */
public final class ForceChunkedMultipartInterceptor implements Interceptor {

    @Override
    public Response intercept(Chain chain) throws IOException {
        Request request = chain.request();
        RequestBody body = request.body();
        if (body == null) {
            return chain.proceed(request);
        }

        MediaType ct = body.contentType();
        if (ct == null || !"multipart".equalsIgnoreCase(ct.type())) {
            return chain.proceed(request);
        }

        // Wrap the body so OkHttp treats the content length as unknown (-1).
        RequestBody chunkedBody = new RequestBody() {
            @Override
            public MediaType contentType() {
                return body.contentType();
            }

            @Override
            public long contentLength() {
                return -1L;
            }

            @Override
            public void writeTo(BufferedSink sink) throws IOException {
                body.writeTo(sink);
            }

            // Keep compatibility across OkHttp versions (OkHttp 4 has isOneShot()).
            public boolean isOneShot() {
                try {
                    java.lang.reflect.Method m = body.getClass().getMethod("isOneShot");
                    Object v = m.invoke(body);
                    return (v instanceof Boolean) ? (Boolean) v : false;
                } catch (Exception ignore) {
                    return false;
                }
            }
        };

        Request newRequest = request.newBuilder()
                .method(request.method(), chunkedBody)
                .removeHeader("Content-Length")
                .build();

        return chain.proceed(newRequest);
    }
}
