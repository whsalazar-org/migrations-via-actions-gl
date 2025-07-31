# **Complexity Analysis of Azure Blob Storage Code**

## **Time & Space Complexity Analysis**

| Function | Time Complexity | Space Complexity |
|----------|-----------------|------------------|
| `getCredential()` | `O(1)` | `O(1)` |
| `getPipeline()` | `O(1)` | `O(1)` |
| `getServiceURL()` | `O(1)` | `O(1)` |
| `getContainerURL()` | `O(1)` | `O(1)` |
| `calculateOptimalBlockSize()` | `O(1)` | `O(1)` |
| `UploadToAzureBlob()` | `O(N/B)` | `O(B)` |
| `StreamUploadToAzureBlob()` | `O(N/B)` | `O(B)` |
| `GeneratePresignedURL()` | `O(1)` | `O(1)` |

- Most operations have **constant time complexity (`O(1)`)** due to caching.
- File uploads and stream uploads depend on **file size (`O(N/B)`)**, where `N` is file size and `B` is block size.
- **Caching consumes `O(1)` space**, since the number of stored credentials, pipelines, and URLs is limited.
- **File and stream uploads require `O(B)` space**, where `B` is the block size (can be up to 100MB).
