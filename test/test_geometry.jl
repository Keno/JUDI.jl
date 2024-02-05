# Unit tests for JUDI Geometry structure
# Philipp Witte (pwitte.slim@gmail.com)
# May 2018
#
# Mathias Louboutin, mlouboutin3@gatech.edu
# Updated July 2020

datapath = joinpath(dirname(pathof(JUDI)))*"/../data/"

@testset "Geometry Unit Test with $(nsrc) sources" for nsrc=[1, 2]
    @timeit TIMEROUTPUT "Geometry (nsrc=$(nsrc))" begin
        # Constructor if nt is not passed
        xsrc = convertToCell(range(100f0, stop=1100f0, length=2)[1:nsrc])
        ysrc = convertToCell(range(0f0, stop=0f0, length=nsrc))
        zsrc = convertToCell(range(20f0, stop=20f0, length=nsrc))

        # Error handling
        @test_throws JUDI.GeometryException Geometry(xsrc, ysrc, zsrc; dt=.75f0, t=70f0)
        @test_throws JUDI.GeometryException Geometry(xsrc, ysrc, zsrc)

        # Geometry for testing
        geometry =  Geometry(xsrc, ysrc, zsrc; dt=2f0, t=1000f0)
        geometry_t =  Geometry(xsrc, ysrc, zsrc; dt=2, t=1000)
        @test geometry_t == geometry

        @test isa(geometry.xloc, Vector{Array{Float32,1}})
        @test isa(geometry.yloc, Vector{Array{Float32,1}})
        @test isa(geometry.zloc, Vector{Array{Float32,1}})
        @test isa(geometry.nt, Vector{Int})
        @test isa(geometry.dt, Vector{Float32})
        @test isa(geometry.t, Vector{Float32})
        @test isa(geometry.t0, Vector{Float32})
        @test isa(geometry.taxis, Vector{<:StepRangeLen{Float32}})

        # Constructor if coordinates are not passed as a cell arrays
        xsrc = range(100f0, stop=1100f0, length=2)[1:nsrc]
        ysrc = range(0f0, stop=0f0, length=nsrc)
        zsrc = range(20f0, stop=20f0, length=nsrc)

        geometry = Geometry(xsrc, ysrc, zsrc; dt=4f0, t=1000f0, nsrc=nsrc)

        @test isa(geometry.xloc, Vector{Array{Float32,1}})
        @test isa(geometry.yloc, Vector{Array{Float32,1}})
        @test isa(geometry.zloc, Vector{Array{Float32,1}})
        @test isa(geometry.nt, Vector{Int})
        @test isa(geometry.dt, Vector{Float32})
        @test isa(geometry.t, Vector{Float32})
        @test isa(geometry.t0, Vector{Float32})
        @test isa(geometry.taxis, Vector{<:StepRangeLen{Float32}})
    
        # Set up source geometry object from in-core data container
        block = segy_read(datapath*"unit_test_shot_records_$(nsrc).segy"; warn_user=false)
        src_geometry = Geometry(block; key="source", segy_depth_key="SourceSurfaceElevation")
        rec_geometry = Geometry(block; key="receiver", segy_depth_key="RecGroupElevation")

        @test isa(src_geometry, GeometryIC{Float32})
        @test isa(rec_geometry, GeometryIC{Float32})
        @test isequal(get_header(block, "SourceSurfaceElevation")[1], src_geometry.zloc[1][1])
        @test isequal(get_header(block, "RecGroupElevation")[1], rec_geometry.zloc[1][1])
        @test isequal(get_header(block, "SourceX")[1], src_geometry.xloc[1][1])
        @test isequal(get_header(block, "GroupX")[1], rec_geometry.xloc[1][1])

        # Set up geometry summary from out-of-core data container
        container = segy_scan(datapath, "unit_test_shot_records_$(nsrc)", ["GroupX", "GroupY", "RecGroupElevation", "SourceSurfaceElevation", "dt"])
        src_geometry = Geometry(container; key="source", segy_depth_key="SourceSurfaceElevation")
        rec_geometry = Geometry(container; key="receiver", segy_depth_key="RecGroupElevation")

        @test isa(src_geometry, GeometryOOC{Float32})
        @test isa(rec_geometry, GeometryOOC{Float32})
        @test isequal(src_geometry.key, "source")
        @test isequal(rec_geometry.key, "receiver")
        @test isequal(src_geometry.segy_depth_key, "SourceSurfaceElevation")
        @test isequal(rec_geometry.segy_depth_key, "RecGroupElevation")
        @test isequal(prod(size(block.data)), sum(rec_geometry.nrec .* rec_geometry.nt))

        # Set up geometry summary from out-of-core data container passed as cell array
        container_cell = Array{SegyIO.SeisCon}(undef, nsrc)
        for j=1:nsrc
            container_cell[j] = split(container, j)
        end

        src_geometry = Geometry(container_cell; key="source", segy_depth_key="SourceSurfaceElevation")
        rec_geometry = Geometry(container_cell; key="receiver", segy_depth_key="RecGroupElevation")

        @test isa(src_geometry, GeometryOOC{Float32})
        @test isa(rec_geometry, GeometryOOC{Float32})
        @test isequal(src_geometry.key, "source")
        @test isequal(rec_geometry.key, "receiver")
        @test isequal(src_geometry.segy_depth_key, "SourceSurfaceElevation")
        @test isequal(rec_geometry.segy_depth_key, "RecGroupElevation")
        @test isequal(prod(size(block.data)), sum(rec_geometry.nrec .* rec_geometry.nt))

        # Load geometry from out-of-core Geometry container
        src_geometry_ic = Geometry(src_geometry)
        rec_geometry_ic = Geometry(rec_geometry)

        @test isa(src_geometry_ic, GeometryIC{Float32})
        @test isa(rec_geometry_ic, GeometryIC{Float32})
        @test isequal(get_header(block, "SourceSurfaceElevation")[1], src_geometry_ic.zloc[1][1])
        @test isequal(get_header(block, "RecGroupElevation")[1], rec_geometry_ic.zloc[1][1])
        @test isequal(get_header(block, "SourceX")[1], src_geometry_ic.xloc[1][1])
        @test isequal(get_header(block, "GroupX")[1], rec_geometry_ic.xloc[1][1])

        # Subsample in-core geometry structure
        src_geometry_sub = subsample(src_geometry_ic, 1)
        @test isa(src_geometry_sub, GeometryIC{Float32})
        @test isequal(length(src_geometry_sub.xloc), 1)
        src_geometry_sub = subsample(src_geometry_ic, 1:1)
        @test isa(src_geometry_sub, GeometryIC{Float32})
        @test isequal(length(src_geometry_sub.xloc), 1)

        inds = nsrc > 1 ? (1:nsrc) : 1
        src_geometry_sub = subsample(src_geometry_ic, inds)
        @test isa(src_geometry_sub, GeometryIC{Float32})
        @test isequal(length(src_geometry_sub.xloc), nsrc)

        # Subsample out-of-core geometry structure
        src_geometry_sub = subsample(src_geometry, 1)
        @test isa(src_geometry_sub, GeometryOOC{Float32})
        @test isequal(length(src_geometry_sub.dt), 1)
        @test isequal(src_geometry_sub.segy_depth_key, "SourceSurfaceElevation")

        src_geometry_sub = subsample(src_geometry, inds)
        @test isa(src_geometry_sub, GeometryOOC{Float32})
        @test isequal(length(src_geometry_sub.dt), nsrc)
        @test isequal(src_geometry_sub.segy_depth_key, "SourceSurfaceElevation")

        # Compare if geometries match
        @test compareGeometry(src_geometry_ic, src_geometry_ic)
        @test compareGeometry(rec_geometry_ic, rec_geometry_ic)

        @test compareGeometry(src_geometry, src_geometry)
        @test compareGeometry(rec_geometry, rec_geometry)

        # test supershot geometry
        if nsrc == 2
            # same geom
            geometry = Geometry(xsrc, ysrc, zsrc; dt=4f0, t=1000f0, nsrc=nsrc)
            sgeom = super_shot_geometry(geometry)
            @test get_nsrc(sgeom) == 1
            @test sgeom.xloc[1] == xsrc
            @test sgeom.yloc[1] == ysrc
            @test sgeom.zloc[1] == zsrc
            @test sgeom.dt[1] == 4f0
            @test sgeom.t[1] == 1000f0
            # now make two geoms
            xall = collect(1f0:4f0)
            geometry = Geometry([[1f0, 2f0], [.5f0, 1.75f0]], [[0f0], [0f0]], [[0f0, 0f0], [0f0, 0f0]]; dt=4f0, t=1000f0)
            sgeom = super_shot_geometry(geometry)
            @test get_nsrc(sgeom) == 1
            @test sgeom.xloc[1] == [.5f0, 1f0, 1.75f0, 2f0]
            @test sgeom.yloc[1] == [0f0]
            @test sgeom.zloc[1] == zeros(Float32, 4)
            @test sgeom.dt[1] == 4f0
            @test sgeom.t[1] == 1000f0
        end

    end
end
