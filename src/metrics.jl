import Distances
struct CheckedEuclidean <: Distances.UnionMinkowskiMetric end

@inline (dist::CheckedEuclidean)(a, b) = Distances._evaluate(dist, a, b, Distances.parameters(dist))
@inline Distances.eval_op(::CheckedEuclidean, ai::Number, bi::Number) = abs(ai - bi)
@inline Distances.eval_op(::CheckedEuclidean, ai::Integer, bi::Integer) = Base.Checked.abs(Base.Checked.checked_sub(ai, bi))
Distances.eval_end(::CheckedEuclidean, s) = s


@testitem "CheckedEuclidean" begin
    using Distances
    @test evaluate(RQADeforestation.CheckedEuclidean(), 2, 5) == evaluate(Euclidean(), 2, 5)
end