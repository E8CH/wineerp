# wineerp_api.api.UtilsApi

## Load the API package
```dart
import 'package:wineerp_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**healthApiV1HealthGet**](UtilsApi.md#healthapiv1healthget) | **GET** /api/v1/health | Health


# **healthApiV1HealthGet**
> BuiltMap<String, String> healthApiV1HealthGet()

Health

### Example
```dart
import 'package:wineerp_api/api.dart';

final api = WineerpApi().getUtilsApi();

try {
    final response = api.healthApiV1HealthGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling UtilsApi->healthApiV1HealthGet: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**BuiltMap&lt;String, String&gt;**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

