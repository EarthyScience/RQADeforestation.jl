"""
    smooth(a, b, γ)

Weighted average of `a` and `b` with weight `γ`.

``(1 - γ) * a + γ * b``
"""
smooth(a, b, γ) = a + γ * (b - a)

struct WeightedFit
    mx::Float64
    my::Float64
    mxx::Float64
    mxy::Float64
    mw::Float64
    n::Int64
end
WeightedFit() = WeightedFit(0.0, 0.0, 0.0, 0.0, 0.0, 0)
function finalizewlinreg(f::WeightedFit)
    b = (f.mxy - f.mx * f.my) / (f.mxx - f.mx * f.mx)
    a = f.my - b * f.mx
    a, b
end
@inline function smoowthwlinfit(xi, yi, wi, f::WeightedFit)
    n = f.n + 1
    mw = smooth(f.mw, wi, inv(n))
    updateweight = wi / (mw * n)
    mx = smooth(f.mx, xi, updateweight)
    my = smooth(f.my, yi, updateweight)
    mxx = smooth(f.mxx, xi * xi, updateweight)
    mxy = smooth(f.mxy, xi * yi, updateweight)
    return WeightedFit(mx, my, mxx, mxy, mw, n)
end

function wlinreg(x, y, w)
    f = WeightedFit()
    @inbounds for i in eachindex(x, y, w)
        f = smoowthwlinfit(x[i], y[i], w[i], f)
    end
    finalizewlinreg(f)
end
