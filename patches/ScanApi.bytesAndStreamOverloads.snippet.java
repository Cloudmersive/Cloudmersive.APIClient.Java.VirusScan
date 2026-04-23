  // ============================================================
  // scanFileAdvanced overloads -- byte[] and InputStream
  //
  // Added post-generation (see build.ps1) so callers can scan
  // in-memory content without first writing it to a temp File.
  // The File-based overload generated upstream by openapi-generator
  // is left untouched.
  //
  // The InputStream overload reads the stream fully into a byte
  // array and delegates to the byte[] path; callers that need
  // true streaming should pre-buffer themselves or use the File
  // overload.
  // ============================================================

  public VirusScanAdvancedResult scanFileAdvanced(byte[] inputBytes, String fileName, Boolean allowExecutables, Boolean allowInvalidFiles, Boolean allowScripts, Boolean allowPasswordProtectedFiles, Boolean allowMacros, Boolean allowXmlExternalEntities, Boolean allowInsecureDeserialization, Boolean allowHtml, Boolean allowUnsafeArchives, Boolean allowOleEmbeddedObject, Boolean allowUnwantedAction, String options, String restrictFileTypes) throws ApiException {
    ApiResponse<VirusScanAdvancedResult> localVarResponse = scanFileAdvancedWithHttpInfo(inputBytes, fileName, allowExecutables, allowInvalidFiles, allowScripts, allowPasswordProtectedFiles, allowMacros, allowXmlExternalEntities, allowInsecureDeserialization, allowHtml, allowUnsafeArchives, allowOleEmbeddedObject, allowUnwantedAction, options, restrictFileTypes);
    return localVarResponse.getData();
  }

  public VirusScanAdvancedResult scanFileAdvanced(InputStream inputStream, String fileName, Boolean allowExecutables, Boolean allowInvalidFiles, Boolean allowScripts, Boolean allowPasswordProtectedFiles, Boolean allowMacros, Boolean allowXmlExternalEntities, Boolean allowInsecureDeserialization, Boolean allowHtml, Boolean allowUnsafeArchives, Boolean allowOleEmbeddedObject, Boolean allowUnwantedAction, String options, String restrictFileTypes) throws ApiException {
    if (inputStream == null) {
      throw new ApiException(400, "Missing the required parameter 'inputStream' when calling scanFileAdvanced");
    }
    byte[] inputBytes;
    try {
      inputBytes = inputStream.readAllBytes();
    } catch (IOException e) {
      throw new ApiException(e);
    }
    return scanFileAdvanced(inputBytes, fileName, allowExecutables, allowInvalidFiles, allowScripts, allowPasswordProtectedFiles, allowMacros, allowXmlExternalEntities, allowInsecureDeserialization, allowHtml, allowUnsafeArchives, allowOleEmbeddedObject, allowUnwantedAction, options, restrictFileTypes);
  }

  public ApiResponse<VirusScanAdvancedResult> scanFileAdvancedWithHttpInfo(byte[] inputBytes, String fileName, Boolean allowExecutables, Boolean allowInvalidFiles, Boolean allowScripts, Boolean allowPasswordProtectedFiles, Boolean allowMacros, Boolean allowXmlExternalEntities, Boolean allowInsecureDeserialization, Boolean allowHtml, Boolean allowUnsafeArchives, Boolean allowOleEmbeddedObject, Boolean allowUnwantedAction, String options, String restrictFileTypes) throws ApiException {
    HttpRequest.Builder localVarRequestBuilder = scanFileAdvancedRequestBuilderFromBytes(inputBytes, fileName, allowExecutables, allowInvalidFiles, allowScripts, allowPasswordProtectedFiles, allowMacros, allowXmlExternalEntities, allowInsecureDeserialization, allowHtml, allowUnsafeArchives, allowOleEmbeddedObject, allowUnwantedAction, options, restrictFileTypes);
    try {
      HttpResponse<InputStream> localVarResponse = memberVarHttpClient.send(
          localVarRequestBuilder.build(),
          HttpResponse.BodyHandlers.ofInputStream());
      if (memberVarResponseInterceptor != null) {
        memberVarResponseInterceptor.accept(localVarResponse);
      }
      try {
        if (localVarResponse.statusCode()/ 100 != 2) {
          throw getApiException("scanFileAdvanced", localVarResponse);
        }
        if (localVarResponse.body() == null) {
          return new ApiResponse<VirusScanAdvancedResult>(
              localVarResponse.statusCode(),
              localVarResponse.headers().map(),
              null
          );
        }

        String responseBody = new String(localVarResponse.body().readAllBytes());
        localVarResponse.body().close();

        return new ApiResponse<VirusScanAdvancedResult>(
            localVarResponse.statusCode(),
            localVarResponse.headers().map(),
            responseBody.isBlank()? null: memberVarObjectMapper.readValue(responseBody, new TypeReference<VirusScanAdvancedResult>() {})
        );
      } finally {
      }
    } catch (IOException e) {
      throw new ApiException(e);
    }
    catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new ApiException(e);
    }
  }

  private HttpRequest.Builder scanFileAdvancedRequestBuilderFromBytes(byte[] inputBytes, String fileName, Boolean allowExecutables, Boolean allowInvalidFiles, Boolean allowScripts, Boolean allowPasswordProtectedFiles, Boolean allowMacros, Boolean allowXmlExternalEntities, Boolean allowInsecureDeserialization, Boolean allowHtml, Boolean allowUnsafeArchives, Boolean allowOleEmbeddedObject, Boolean allowUnwantedAction, String options, String restrictFileTypes) throws ApiException {
    if (inputBytes == null) {
      throw new ApiException(400, "Missing the required parameter 'inputBytes' when calling scanFileAdvanced");
    }

    HttpRequest.Builder localVarRequestBuilder = HttpRequest.newBuilder();

    String localVarPath = "/virus/scan/file/advanced";

    localVarRequestBuilder.uri(URI.create(memberVarBaseUri + localVarPath));

    if (fileName != null) {
      localVarRequestBuilder.header("fileName", fileName.toString());
    }
    if (allowExecutables != null) {
      localVarRequestBuilder.header("allowExecutables", allowExecutables.toString());
    }
    if (allowInvalidFiles != null) {
      localVarRequestBuilder.header("allowInvalidFiles", allowInvalidFiles.toString());
    }
    if (allowScripts != null) {
      localVarRequestBuilder.header("allowScripts", allowScripts.toString());
    }
    if (allowPasswordProtectedFiles != null) {
      localVarRequestBuilder.header("allowPasswordProtectedFiles", allowPasswordProtectedFiles.toString());
    }
    if (allowMacros != null) {
      localVarRequestBuilder.header("allowMacros", allowMacros.toString());
    }
    if (allowXmlExternalEntities != null) {
      localVarRequestBuilder.header("allowXmlExternalEntities", allowXmlExternalEntities.toString());
    }
    if (allowInsecureDeserialization != null) {
      localVarRequestBuilder.header("allowInsecureDeserialization", allowInsecureDeserialization.toString());
    }
    if (allowHtml != null) {
      localVarRequestBuilder.header("allowHtml", allowHtml.toString());
    }
    if (allowUnsafeArchives != null) {
      localVarRequestBuilder.header("allowUnsafeArchives", allowUnsafeArchives.toString());
    }
    if (allowOleEmbeddedObject != null) {
      localVarRequestBuilder.header("allowOleEmbeddedObject", allowOleEmbeddedObject.toString());
    }
    if (allowUnwantedAction != null) {
      localVarRequestBuilder.header("allowUnwantedAction", allowUnwantedAction.toString());
    }
    if (options != null) {
      localVarRequestBuilder.header("options", options.toString());
    }
    if (restrictFileTypes != null) {
      localVarRequestBuilder.header("restrictFileTypes", restrictFileTypes.toString());
    }
    localVarRequestBuilder.header("Accept", "application/json, text/json, application/xml, text/xml");

    String effectiveFileName = (fileName != null && !fileName.isEmpty()) ? fileName : "inputFile";
    MultipartEntityBuilder multiPartBuilder = MultipartEntityBuilder.create();
    multiPartBuilder.addBinaryBody("inputFile", inputBytes, org.apache.http.entity.ContentType.APPLICATION_OCTET_STREAM, effectiveFileName);
    HttpEntity entity = multiPartBuilder.build();
    HttpRequest.BodyPublisher formDataPublisher;
    if (ApiClient.isChunkedTransferEnabled()) {
        // Stream bytes directly as application/octet-stream with chunked
        // transfer encoding (no multipart framing, no Content-Length header).
        formDataPublisher = HttpRequest.BodyPublishers.ofByteArray(inputBytes);
        localVarRequestBuilder
            .header("Content-Type", "application/octet-stream")
            .method("POST", formDataPublisher);
    } else {
        ByteArrayOutputStream formOutputStream = new ByteArrayOutputStream();
        try {
            entity.writeTo(formOutputStream);
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        formDataPublisher = HttpRequest.BodyPublishers.ofByteArray(formOutputStream.toByteArray());
        localVarRequestBuilder
            .header("Content-Type", entity.getContentType().getValue())
            .method("POST", formDataPublisher);
    }
    if (memberVarReadTimeout != null) {
      localVarRequestBuilder.timeout(memberVarReadTimeout);
    }
    if (memberVarInterceptor != null) {
      memberVarInterceptor.accept(localVarRequestBuilder);
    }
    return localVarRequestBuilder;
  }
