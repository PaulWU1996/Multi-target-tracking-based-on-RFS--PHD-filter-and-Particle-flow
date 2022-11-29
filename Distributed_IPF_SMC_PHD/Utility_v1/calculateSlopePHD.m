function [slope, log_jacobian_det] = calculateSlopePHD(z_current,vgset,setup,lambda,step_size,surv_particle_num,Cz,nSi)
% Calculate the slopes of each particle during the particle flow.
%
% Input:
% z_current: a column vector of the measurements at the current time step.
% vg: a struct that contains the filter output
% ps: a struct with filter and simulation parameters
% lambda: a scalar in [0,1] that indicates the psuedo-time of the flow
% step_size: a scalar that shows the step size.
%
% Output:
% slope: a matrix of size dim x nParticle that contains the slopes of each particle during the flow.
% log_jacobian_det: a row vector containing the log of Jacobian determinants for
%               each particle that are used in the proposal calculation.
%%%%%%%%%%%%%%%%%
log_jacobian_det = zeros(1,setup.nParticle);
slope = zeros(2,surv_particle_num);%zeros(2,size(vgset,2));
if lambda >0
    [slope_real, log_jacobian_det, B] = IPF_homotopy_PHD(z_current,vgset,setup,lambda,step_size,Cz,surv_particle_num,nSi);
    %[slope_real, log_jacobian_det] = homotopy_LocalPHD(z_current,vgset,setup,lambda,step_size)
    %[slope, log_jacobian_det] = NPF_homotopy_PHDV2(z_current,vgset,setup,lambda,step_size,Cz);
    %[slope, log_jacobian_det] = NPF_single_homotopy_PHDV2(z_current,vgset,setup,lambda,step_size,Cz);
end