//! Conservative, OS-neutral comparison token; not a content checksum.
pub const FileStamp = struct {
    inode: u64,
    size: u64,
    mtime: i96,
    ctime: i96,
    mode: u32,
    pub fn eql(a: FileStamp, b: FileStamp) bool {
        return a.inode == b.inode and a.size == b.size and a.mtime == b.mtime and a.ctime == b.ctime and a.mode == b.mode;
    }
};
