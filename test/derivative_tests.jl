using DataInterpolations, Test
using FiniteDifferences
using DataInterpolations: derivative
using Symbolics
using StableRNGs
using RegularizationTools
using Optim
using ForwardDiff

function test_derivatives(method, u, t; args = [], kwargs = [], name::String)
    func = method(u, t, args...; kwargs..., extrapolate = true)
    trange = collect(range(minimum(t) - 5.0, maximum(t) + 5.0, step = 0.1))
    trange_exclude = filter(x -> !in(x, t), trange)
    @testset "$name" begin
        # Rest of the points
        for _t in trange_exclude
            cdiff = central_fdm(5, 1; geom = true)(func, _t)
            adiff = derivative(func, _t)
            @test isapprox(cdiff, adiff, atol = 1e-8)
        end

        # Interpolation time points
        for _t in t[2:(end - 1)]
            fdiff = if func isa BSplineInterpolation || func isa BSplineApprox
                forward_fdm(5, 1; geom = true)(func, _t)
            else
                backward_fdm(5, 1; geom = true)(func, _t)
            end
            adiff = derivative(func, _t)
            @test isapprox(fdiff, adiff, atol = 1e-8)
        end

        # t = t0
        fdiff = forward_fdm(5, 1; geom = true)(func, t[1])
        adiff = derivative(func, t[1])
        @test isapprox(fdiff, adiff, atol = 1e-8)

        # t = tend
        fdiff = backward_fdm(5, 1; geom = true)(func, t[end])
        adiff = derivative(func, t[end])
        @test isapprox(fdiff, adiff, atol = 1e-8)
    end
    func = method(u, t, args...)
    @test_throws DataInterpolations.ExtrapolationError derivative(func, t[1] - 1.0)
    @test_throws DataInterpolations.ExtrapolationError derivative(func, t[end] + 1.0)
end

@testset "Linear Interpolation" begin
    u = vcat(collect(1:5), 2 * collect(6:10))
    t = 1.0collect(1:10)
    test_derivatives(LinearInterpolation, u, t; name = "Linear Interpolation (Vector)")
    u = vcat(2.0collect(1:10)', 3.0collect(1:10)')
    test_derivatives(LinearInterpolation, u, t; name = "Linear Interpolation (Matrix)")
end

@testset "Quadratic Interpolation" begin
    u = [1.0, 4.0, 9.0, 16.0]
    t = [1.0, 2.0, 3.0, 4.0]
    test_derivatives(QuadraticInterpolation,
        u,
        t;
        name = "Quadratic Interpolation (Vector)")
    test_derivatives(QuadraticInterpolation,
        u,
        t;
        args = [:Backward],
        name = "Quadratic Interpolation (Vector), backward")
    u = [1.0 4.0 9.0 16.0; 1.0 4.0 9.0 16.0]
    test_derivatives(QuadraticInterpolation,
        u,
        t;
        name = "Quadratic Interpolation (Matrix)")
end

@testset "Lagrange Interpolation" begin
    u = [1.0, 4.0, 9.0]
    t = [1.0, 2.0, 3.0]
    test_derivatives(LagrangeInterpolation, u, t; name = "Lagrange Interpolation (Vector)")
    u = [1.0 4.0 9.0; 1.0 2.0 3.0]
    test_derivatives(LagrangeInterpolation, u, t; name = "Lagrange Interpolation (Matrix)")
    u = [[1.0, 4.0, 9.0], [3.0, 7.0, 4.0], [5.0, 4.0, 1.0]]
    test_derivatives(LagrangeInterpolation,
        u,
        t;
        name = "Lagrange Interpolation (Vector of Vectors)")
    u = [[3.0 1.0 4.0; 1.0 5.0 9.0], [2.0 6.0 5.0; 3.0 5.0 8.0], [9.0 7.0 9.0; 3.0 2.0 3.0]]
    test_derivatives(LagrangeInterpolation,
        u,
        t;
        name = "Lagrange Interpolation (Vector of Matrices)")
end

@testset "Akima Interpolation" begin
    u = [0.0, 2.0, 1.0, 3.0, 2.0, 6.0, 5.5, 5.5, 2.7, 5.1, 3.0]
    t = collect(0.0:10.0)
    test_derivatives(AkimaInterpolation, u, t; name = "Akima Interpolation")
    @testset "Akima smooth derivative at end points" begin
        A = AkimaInterpolation(u, t)
        @test derivative(A, t[1]) ≈ derivative(A, nextfloat(t[1]))
        @test derivative(A, t[end]) ≈ derivative(A, prevfloat(t[end]))
    end
end

@testset "Quadratic Spline" begin
    u = [0.0, 1.0, 3.0]
    t = [-1.0, 0.0, 1.0]
    test_derivatives(QuadraticSpline, u, t; name = "Quadratic Interpolation (Vector)")
    u = [[1.0, 2.0, 9.0], [3.0, 7.0, 5.0], [5.0, 4.0, 1.0]]
    test_derivatives(QuadraticSpline,
        u,
        t;
        name = "Quadratic Interpolation (Vector of Vectors)")
    u = [[1.0 4.0 9.0; 5.0 9.0 2.0], [3.0 7.0 4.0; 6.0 5.0 3.0], [5.0 4.0 1.0; 2.0 3.0 8.0]]
    test_derivatives(QuadraticSpline,
        u,
        t;
        name = "Quadratic Interpolation (Vector of Matrices)")
end

@testset "Cubic Spline" begin
    u = [0.0, 1.0, 3.0]
    t = [-1.0, 0.0, 1.0]
    test_derivatives(CubicSpline, u, t; name = "Cubic Spline Interpolation (Vector)")
    u = [[1.0, 2.0, 9.0], [3.0, 7.0, 5.0], [5.0, 4.0, 1.0]]
    test_derivatives(CubicSpline,
        u,
        t;
        name = "Cubic Spline Interpolation (Vector of Vectors)")
    u = [[1.0 4.0 9.0; 5.0 9.0 2.0], [3.0 7.0 4.0; 6.0 5.0 3.0], [5.0 4.0 1.0; 2.0 3.0 8.0]]
    test_derivatives(CubicSpline,
        u,
        t;
        name = "Cubic Spline Interpolation (Vector of Matrices)")
end

@testset "BSplines" begin
    t = [0, 62.25, 109.66, 162.66, 205.8, 252.3]
    u = [14.7, 11.51, 10.41, 14.95, 12.24, 11.22]
    test_derivatives(BSplineInterpolation,
        u,
        t;
        args = [2,
            :Uniform,
            :Uniform],
        name = "BSpline Interpolation (Uniform, Uniform)")
    test_derivatives(BSplineInterpolation,
        u,
        t;
        args = [2,
            :ArcLen,
            :Average],
        name = "BSpline Interpolation (Arclen, Average)")
    test_derivatives(BSplineApprox,
        u,
        t;
        args = [
            3,
            4,
            :Uniform,
            :Uniform],
        name = "BSpline Approx (Uniform, Uniform)")
end

@testset "RegularizationSmooth" begin
    npts = 50
    xmin = 0.0
    xspan = 3 / 2 * π
    x = collect(range(xmin, xmin + xspan, length = npts))
    rng = StableRNG(655)
    x = x + xspan / npts * (rand(rng, npts) .- 0.5)
    # select a subset randomly
    idx = unique(rand(rng, collect(eachindex(x)), 20))
    t = x[unique(idx)]
    npts = length(t)
    ut = sin.(t)
    stdev = 1e-1 * maximum(ut)
    u = ut + stdev * randn(rng, npts)
    # data must be ordered if t̂ is not provided
    idx = sortperm(t)
    tₒ = t[idx]
    uₒ = u[idx]
    A = RegularizationSmooth(uₒ, tₒ; alg = :fixed)
    test_derivatives(RegularizationSmooth,
        uₒ,
        tₒ;
        kwargs = [:alg => :fixed],
        name = "RegularizationSmooth")
end

@testset "Curvefit" begin
    rng = StableRNG(12345)
    model(x, p) = @. p[1] / (1 + exp(x - p[2]))
    t = range(-10, stop = 10, length = 40)
    u = model(t, [1.0, 2.0]) + 0.01 * randn(rng, length(t))
    p0 = [0.5, 0.5]
    test_derivatives(Curvefit, u, t; args = [model, p0, LBFGS()], name = "Curvefit")
end

@testset "Symbolic derivatives" begin
    u = [0.0, 1.5, 0.0]
    t = [0.0, 0.5, 1.0]
    A = QuadraticSpline(u, t)
    @variables τ, ω(τ)
    D = Symbolics.Differential(τ)
    expr = A(ω)
    @test isequal(Symbolics.derivative(expr, τ), D(ω) * DataInterpolations.derivative(A, ω))

    derivexpr = expand_derivatives(substitute(D(A(ω)), Dict(ω => 0.5τ)))
    symfunc = Symbolics.build_function(derivexpr, τ; expression = Val{false})
    @test symfunc(0.5) == 0.5 * 3

    u = [0.0, 1.5, 0.0]
    t = [0.0, 0.5, 1.0]
    @variables τ
    D = Symbolics.Differential(τ)
    f = LinearInterpolation(u, t)
    df = expand_derivatives(D(f(τ)))
    symfunc = Symbolics.build_function(df, τ; expression = Val{false})
    ts = 0.0:0.1:1.0
    @test all(map(ti -> symfunc(ti) == derivative(f, ti), ts))
end
