# wineerp_api.api.DefaultApi

## Load the API package
```dart
import 'package:wineerp_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**rootGet**](DefaultApi.md#rootget) | **GET** / | Root


# **rootGet**
> BuiltMap<String, String> rootGet()

Root

### Example
```dart
import 'package:wineerp_api/api.dart';

final api = WineerpApi().getDefaultApi();

try {
    final response = api.rootGet();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->rootGet: $e\n');
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

