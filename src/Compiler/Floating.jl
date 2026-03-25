# Floating.jl - Floating element positioning algorithm
#
# Pure Julia implementation of the floating positioning algorithm.
# Compiles to JavaScript via JavaScriptTarget.jl for @island components.

# Side constants (i32)
const SIDE_BOTTOM = Int32(0)
const SIDE_TOP    = Int32(1)
const SIDE_RIGHT  = Int32(2)
const SIDE_LEFT   = Int32(3)

# Alignment constants (i32)
const ALIGN_START  = Int32(0)
const ALIGN_CENTER = Int32(1)
const ALIGN_END    = Int32(2)

# Viewport padding (matches suite.js pad = 4)
const VIEWPORT_PAD = 4.0

"""
    compute_position(ref_x, ref_y, ref_w, ref_h, flt_w, flt_h, vw, vh, side, align, side_offset, align_offset) -> (x, y, actual_side)

Compute the (x, y) position for a floating element relative to a reference element,
with viewport collision avoidance.

# Arguments
- `ref_x`, `ref_y`, `ref_w`, `ref_h`: Reference element bounding rect (from getBoundingClientRect)
- `flt_w`, `flt_h`: Floating element width and height
- `vw`, `vh`: Viewport width and height
- `side`: Desired placement side (SIDE_BOTTOM=0, SIDE_TOP=1, SIDE_RIGHT=2, SIDE_LEFT=3)
- `align`: Alignment along the side (ALIGN_START=0, ALIGN_CENTER=1, ALIGN_END=2)
- `side_offset`: Distance from reference element along the side axis
- `align_offset`: Offset along the alignment axis

# Returns
Named tuple `(x::Float64, y::Float64, actual_side::Int32)` where `actual_side` may
differ from `side` if the element was flipped to avoid viewport overflow.
"""
function compute_position(
    ref_x::Float64, ref_y::Float64, ref_w::Float64, ref_h::Float64,
    flt_w::Float64, flt_h::Float64,
    vw::Float64, vh::Float64,
    side::Int32, align::Int32,
    side_offset::Float64, align_offset::Float64
)
    pad = VIEWPORT_PAD
    actual_side = side

    # Alignment helper: compute position along alignment axis
    # ref_start: start of reference edge, ref_size: reference dimension, flt_size: floating dimension
    function align_pos(ref_start::Float64, ref_size::Float64, flt_size::Float64)
        if align == ALIGN_START
            return ref_start + align_offset
        elseif align == ALIGN_END
            return ref_start + ref_size - flt_size + align_offset
        else  # ALIGN_CENTER
            return ref_start + (ref_size - flt_size) / 2.0 + align_offset
        end
    end

    # Compute initial position based on desired side
    top = 0.0
    left = 0.0

    if side == SIDE_BOTTOM
        top = ref_y + ref_h + side_offset
        left = align_pos(ref_x, ref_w, flt_w)
    elseif side == SIDE_TOP
        top = ref_y - flt_h - side_offset
        left = align_pos(ref_x, ref_w, flt_w)
    elseif side == SIDE_RIGHT
        left = ref_x + ref_w + side_offset
        top = align_pos(ref_y, ref_h, flt_h)
    else  # SIDE_LEFT
        left = ref_x - flt_w - side_offset
        top = align_pos(ref_y, ref_h, flt_h)
    end

    # Flip if colliding with viewport edge
    if actual_side == SIDE_BOTTOM && top + flt_h > vh - pad
        flipped = ref_y - flt_h - side_offset
        if flipped >= pad
            top = flipped
            actual_side = SIDE_TOP
        end
    elseif actual_side == SIDE_TOP && top < pad
        flipped = ref_y + ref_h + side_offset
        if flipped + flt_h <= vh - pad
            top = flipped
            actual_side = SIDE_BOTTOM
        end
    elseif actual_side == SIDE_RIGHT && left + flt_w > vw - pad
        flipped = ref_x - flt_w - side_offset
        if flipped >= pad
            left = flipped
            actual_side = SIDE_LEFT
        end
    elseif actual_side == SIDE_LEFT && left < pad
        flipped = ref_x + ref_w + side_offset
        if flipped + flt_w <= vw - pad
            left = flipped
            actual_side = SIDE_RIGHT
        end
    end

    # Shift to keep within viewport bounds
    left = max(pad, min(left, vw - flt_w - pad))
    top = max(pad, min(top, vh - flt_h - pad))

    return (x=left, y=top, actual_side=actual_side)
end
