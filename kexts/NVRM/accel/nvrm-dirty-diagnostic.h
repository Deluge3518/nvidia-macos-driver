#pragma once
// Diagnostic classification only. Keep the public NVRM_SS_NO_CACHE ABI unchanged.
enum NMDirtyReason {
    NMDirtyOK, NMDirtyNoCache, NMDirtyNoResource, NMDirtyNoMemory,
    NMDirtyNoHandle, NMDirtyWrongType, NMDirtyRetiredFlags,
    NMDirtyNoValidity, NMDirtyBadPlane, NMDirtyPendingFull, NMDirtyReasonCount
};
static inline NMDirtyReason nmDirtyResourceReason(bool cache, bool resource, bool memory, bool handle)
{
    if (!cache) return NMDirtyNoCache;
    if (!resource) return NMDirtyNoResource;
    if (!memory) return NMDirtyNoMemory;
    if (!handle) return NMDirtyNoHandle;
    return NMDirtyOK;
}
static inline NMDirtyReason nmDirtyValidityReason(unsigned type, unsigned flags, bool validity, unsigned plane)
{
    if (type != 0xc0) return NMDirtyWrongType;
    if (flags & 0x8000) return NMDirtyRetiredFlags;
    if (!validity) return NMDirtyNoValidity;
    if (plane > 15) return NMDirtyBadPlane;
    return NMDirtyOK;
}
static inline const char *nmDirtyReasonName(NMDirtyReason reason)
{
    switch (reason) {
    case NMDirtyOK: return "ok";
    case NMDirtyNoCache: return "no-family-cache";
    case NMDirtyNoResource: return "no-nv-resource";
    case NMDirtyNoMemory: return "no-vidmem";
    case NMDirtyNoHandle: return "no-kapi-memory";
    case NMDirtyWrongType: return "resource-type";
    case NMDirtyRetiredFlags: return "resource-flags-8000";
    case NMDirtyNoValidity: return "no-validity-table";
    case NMDirtyBadPlane: return "plane-out-of-range";
    case NMDirtyPendingFull: return "pending-table-unavailable";
    default: return "unknown";
    }
}
static inline bool nmDirtyShouldLog(unsigned count)
{
    return count && (count <= 8 || (count & (count - 1)) == 0);
}
