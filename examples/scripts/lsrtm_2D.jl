# LS-RTM of the 2D Marmousi model using LSQR
# Author: ziyi.yin@gatech.edu
# Date: June 2022

using Statistics, Random, LinearAlgebra, JOLI, Distributed
using JUDI, SegyIO, HDF5, PyPlot, IterativeSolvers


# Load migration velocity model
if ~isfile("$(JUDI.JUDI_DATA)/marmousi_model.h5")
    ftp_data("ftp://slim.gatech.edu/data/SoftwareRelease/Imaging.jl/2DLSRTM/marmousi_model.h5")
end
n, d, o, m0 = read(h5open("$(JUDI.JUDI_DATA)/marmousi_model.h5", "r"), "n", "d", "o", "m0")

# Set up model structure
model0 = Model(n, d, o, m0)
grad_mem = 40 # Based on n and CFL condition

# Coarsen for CI
if get(ENV, "CI", nothing) == "true"
    model0 = Model(ceil.(Int, n ./ 2), d .* 2, o, m0[1:2:end, 1:2:end])
    grad_mem = 5
end

# Load data
if ~isfile("$(JUDI.JUDI_DATA)/marmousi_2D.segy")
    ftp_data("ftp://slim.gatech.edu/data/SoftwareRelease/Imaging.jl/2DLSRTM/marmousi_2D.segy")
end
block = segy_scan(JUDI.JUDI_DATA, "marmousi_2D.segy", ["GroupX","GroupY","RecGroupElevation","SourceSurfaceElevation","dt"])
d_lin = judiVector(block)   # linearized observed data

# Set up wavelet
src_geometry = Geometry(block; key = "source", segy_depth_key = "SourceDepth")
wavelet = ricker_wavelet(src_geometry.t[1], src_geometry.dt[1], 0.03)    # 30 Hz wavelet
q = judiVector(src_geometry, wavelet)

###################################################################################################
# Infer subsampling based on free memory
mem = Sys.free_memory()/(1024^3)
t_sub = max(1, ceil(Int, .5*nworkers()*grad_mem/mem))

# Setup operators
opt = Options(subsampling_factor=t_sub, isic=true)  # ~40 GB of memory per source without subsampling
M = judiModeling(model0, q.geometry, d_lin.geometry; options=opt)
J = judiJacobian(M, q)


# Right-hand preconditioners (model topmute)
Mr = judiTopmute(model0; taperwidth=10)
# Left-hand Preconditionners (data top mute)
Ml = judiDataMute(q.geometry, d_lin.geometry)

#' set up number of iterations
niter = parse(Int, get(ENV, "NITER", "10"))
# Default to 64, 5 for CI only with NITER=1
nsrc = 5 * parse(Int, get(ENV, "NITER", "$(q.nsrc ÷ 5)"))
indsrc = randperm(q.nsrc)[1:nsrc]
lsqr_sol = zeros(Float32, prod(model0.n))

# LSQR
dinv = d_lin[indsrc]
Jinv = J[indsrc]

lsqr!(lsqr_sol, Ml[indsrc]*Jinv*Mr, Ml[indsrc]*dinv; maxiter=niter)

# Save final velocity model, function value and history
h5open("lsrtm_marmousi_lsqr_result.h5", "w") do file
    write(file, "x", reshape(lsqr_sol, model0.n))
end

# Plot final image
figure(); imshow(reshape(lsqr_sol, model0.n)', extent = (0, 7.99, 3.19, 0), cmap = "gray", vmin = -3e-2, vmax = 3e-2)
title("LS-RTM with LSQR")
xlabel("Lateral position [km]")
ylabel("Depth [km]")
