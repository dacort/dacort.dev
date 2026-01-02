# 3xplore Implementation Plan

## Overview
Building **3xplore** - a Rust-based S3 explorer shell with archive navigation support. Users can navigate S3 buckets like a Unix shell and `cd` into archives (tar, tar.gz, tar.bz2, zip, gz, bz2) to explore their contents without downloading entire files.

## Core Architecture

### Virtual Filesystem (VFS) Abstraction
The key design is a unified VFS that represents all navigable locations:

```rust
enum VfsNode {
    Root,                          // Lists S3 buckets
    Bucket { name },               // S3 bucket
    Prefix { bucket, prefix },     // S3 "directory" (prefix)
    Object { bucket, key, size },  // S3 object
    Archive { parent, type, index }, // Archive (tar, zip, etc.)
    ArchiveEntry { archive, path } // File/dir inside archive
}
```

Paths map to nodes: `/bucket/prefix/archive.tar.gz/file.txt` → ArchiveEntry node

### Archive Streaming Strategy

**Zip files:**
- Read central directory at end using S3 range request
- Build index mapping filenames to offsets
- Random access to any file via range requests

**Tar files:**
- Stream entire archive once to build header index
- Cache index in memory
- **Challenge:** tar.gz requires decompression from start (can't seek in compressed stream)
- **Solution:** Cache decompressed chunks for tar.gz files

**Standalone gz/bz2:**
- Decompress on-the-fly when cat'd

**Nested archives:**
- Extract inner archive to memory (limit depth to 3)
- Cache extracted archives in LRU cache

### Project Structure
```
3xplore/
├── src/
│   ├── main.rs           # Entry point, REPL loop
│   ├── shell/
│   │   ├── mod.rs        # Shell state, command dispatcher
│   │   └── commands/     # ls.rs, cd.rs, cat.rs
│   ├── vfs/
│   │   ├── node.rs       # VfsNode enum
│   │   ├── path.rs       # Virtual path representation
│   │   └── resolver.rs   # Path resolution logic
│   ├── s3/
│   │   ├── client.rs     # AWS SDK wrapper
│   │   └── stream.rs     # Range request streaming
│   ├── archive/
│   │   ├── mod.rs        # ArchiveHandler trait
│   │   ├── tar.rs        # Tar/tar.gz/tar.bz2
│   │   ├── zip.rs        # Zip support
│   │   ├── gzip.rs       # Standalone .gz
│   │   ├── bzip2.rs      # Standalone .bz2
│   │   └── nested.rs     # Nested archive handling
│   └── cache/
│       └── mod.rs        # In-memory LRU cache for indexes
```

## Key Rust Crates
- `aws-sdk-s3`, `tokio` - S3 operations and async runtime
- `tar`, `zip`, `flate2`, `bzip2` - Archive formats
- `rustyline` - Interactive shell with history/completion
- `colored` - Terminal colors
- `anyhow`, `thiserror` - Error handling
- `lru` - Cache implementation

## Implementation Phases

### Phase 1: Foundation & S3 Navigation
**Goal:** Working shell that can navigate S3 buckets and read files

1. Initialize Cargo project with dependencies
2. Create basic shell REPL with `rustyline`
3. Implement VFS types (`VfsNode`, `VirtualPath`)
4. Create S3 client wrapper
5. Implement commands:
   - `ls` at root (list buckets)
   - `cd` into buckets
   - `ls` in buckets (list prefixes and objects with delimiter)
   - `cd` into prefixes
   - `cat` S3 objects (direct download)
6. Implement path resolver for S3 navigation
7. Add basic error handling and colored output

**Critical files:**
- `/Users/dacort/src/3xplore/Cargo.toml`
- `/Users/dacort/src/3xplore/src/main.rs`
- `/Users/dacort/src/3xplore/src/shell/mod.rs`
- `/Users/dacort/src/3xplore/src/vfs/node.rs`
- `/Users/dacort/src/3xplore/src/vfs/resolver.rs`
- `/Users/dacorn/src/3xplore/src/s3/client.rs`

**Deliverable:** Can navigate S3 buckets and view files like a Unix shell

### Phase 2: Archive Support - Zip
**Goal:** Navigate and read zip files in S3

1. Implement S3 range request streaming (`s3/stream.rs`)
2. Create `ArchiveHandler` trait
3. Implement `ZipHandler`:
   - Find EOCD (End of Central Directory) via range request
   - Parse central directory to build index
   - Extract files using range requests
4. Add archive detection (by extension) to path resolver
5. Update `cd` to handle zip archives
6. Update `ls` to list zip contents
7. Update `cat` to read files from zip
8. Implement in-memory cache for zip indexes

**Critical files:**
- `/Users/dacorn/src/3xplore/src/s3/stream.rs`
- `/Users/dacorn/src/3xplore/src/archive/mod.rs`
- `/Users/dacorn/src/3xplore/src/archive/zip.rs`
- `/Users/dacorn/src/3xplore/src/cache/mod.rs`

**Deliverable:** Can `cd` into zip files and explore contents

### Phase 3: Archive Support - Tar
**Goal:** Navigate and read tar/tar.gz/tar.bz2 files

1. Implement `TarHandler`:
   - Stream archive to build header index
   - Handle uncompressed tar
   - Add gzip decompression layer for tar.gz
   - Add bzip2 decompression layer for tar.bz2
2. Handle tar random access (seek to offset)
3. **Tar.gz challenge:** Implement chunk caching since we can't seek in compressed streams
4. Update resolver to detect tar formats
5. Add tar support to commands

**Critical files:**
- `/Users/dacorn/src/3xplore/src/archive/tar.rs`

**Deliverable:** Can navigate all tar formats

### Phase 4: Standalone Compression & Nested Archives
**Goal:** Support .gz/.bz2 files and archives within archives

1. Implement standalone `GzipHandler` and `Bzip2Handler`
2. Implement nested archive extraction:
   - Detect when archive entry is itself an archive
   - Extract inner archive to memory
   - Support `cd` into nested archives
   - Add depth limiting (max 3 levels)
3. Add LRU cache for extracted nested archives
4. Update all commands to handle nested case

**Critical files:**
- `/Users/dacorn/src/3xplore/src/archive/gzip.rs`
- `/Users/dacorn/src/3xplore/src/archive/bzip2.rs`
- `/Users/dacorn/src/3xplore/src/archive/nested.rs`

**Deliverable:** Can navigate nested archives

### Phase 5: Recursive Listing & Polish
**Goal:** Add `ls -R` and polish the UX

1. Implement `ls -R` (recursive listing):
   - Recursively traverse VFS nodes
   - Include archive contents in output
   - Format tree-like display
2. Add `pwd` command (show current virtual path)
3. Add `help` command
4. Improve error messages
5. Add colored output for different file types
6. Add file size and date formatting
7. Command history and basic tab completion
8. Add progress indicators for slow operations (large archives)

**Deliverable:** Polished, production-ready tool

## Technical Considerations

### Archive Format Trade-offs

**Zip (Best for random access):**
- ✅ Central directory at end enables efficient index building
- ✅ Random access to any file via offsets
- ✅ Well-suited for S3 range requests

**Tar (Sequential format):**
- ⚠️ Must scan entire archive to build index
- ✅ Index cached after first scan
- ❌ Compressed tar (tar.gz) can't seek - must decompress from start

**Solution for tar.gz:** Cache decompressed chunks in memory with LRU eviction

### Memory Management
- Cache archive indexes (small, ~1KB per archive)
- Cache extracted nested archives (larger, use LRU with size limit)
- Default memory limit: 100MB for caches
- Evict based on LRU when limit reached

### Error Handling
- Use `anyhow::Result` for flexibility
- Define custom errors with `thiserror` for specific cases
- User-friendly error messages (e.g., "Archive not found" not "S3 404")

### Path Resolution Algorithm
1. Parse path (absolute vs relative)
2. Tokenize by `/`
3. For each segment, determine node type:
   - At Root: segment is bucket name
   - At Bucket/Prefix: check S3 (prefix vs object)
   - Detect archives by extension
   - Within archive: look up in cached index
4. Handle `..` and `.` for relative navigation

## Success Criteria
- ✅ Can list S3 buckets at root
- ✅ Can navigate into buckets and prefixes
- ✅ Can `cat` S3 objects
- ✅ Can `cd` into all supported archive types
- ✅ Can `cat` files from inside archives
- ✅ Can navigate nested archives (up to 3 levels)
- ✅ `ls -R` includes archive contents
- ✅ Streaming works without downloading entire files
- ✅ Pleasant CLI with colors and history

## Future Enhancements (Post-v1)
- `find` and `grep` commands
- `download` command to copy to local filesystem
- Support for 7z, rar archives
- Persistent disk cache
- Configuration file for settings
- Parallel streaming for large files
