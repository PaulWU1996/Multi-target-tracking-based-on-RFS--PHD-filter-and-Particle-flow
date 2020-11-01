function [Particles]=SequentialMCMC_JointPosteriorv1(ModelParam,Observation,Algo,State)

Particles.Analysis.NoRefinement=0;
Particles.Analysis.AcceptationRefinement=0;
Particles.Analysis.NoJointDraw=0;
Particles.Analysis.AcceptationJointDraw=0;
Particles.Analysis.AcceptationPreviousTerm=0;
Particles.Analysis.NoPreviousTerm=0;
NoMCMCIterations=Algo.NoBurnIn+Algo.Thining*Algo.NoParticles;
NoRefiningSteps=ModelParam.Dimension/Algo.BlockSize;

Particles.Data=zeros(ModelParam.Dimension,Algo.NoParticles,ModelParam.NoTimeSteps);
Particles.AuxVarHMC=zeros(ModelParam.Dimension,Algo.NoParticles,ModelParam.NoTimeSteps);
Particles.Mean=zeros(ModelParam.Dimension,ModelParam.NoTimeSteps);


Candidate.Data=zeros(ModelParam.Dimension,1);
Candidate.LogLikelihood=0;

Chosen.Data=zeros(ModelParam.Dimension,1);
Chosen.LogLikelihood=0;


switch ModelParam.setup.example_name
    case 'Acoustic'
        propparams_no_noise = ModelParam.propparams;
        propparams_no_noise.Q = 0*ModelParam.propparams.Q;
    case 'Septier16'
        propparams_no_noise.W = 0;
    otherwise
        error('The example name does not matche the record');
end

for t=1:ModelParam.NoTimeSteps % Iteration over time samples  
    NumParticles=1;
    for j=1:NoMCMCIterations % MCMC iteraion for one time sample
        if j==1 && t==1    
            Chosen.Data(:,2)=zeros(ModelParam.Dimension,1);
            
            Chosen.Data(:,1)=ModelParam.propparams.propagatefcn(ModelParam.InitialMean,ModelParam.propparams); 
            Chosen.LogLikelihood=ModelParam.likeparams.llh(Chosen.Data(:,1),Observation(:,t),ModelParam.likeparams);
            
        elseif j==1 && t~=1

            UniformPick=ceil(Algo.NoParticles*rand);

            Chosen.Data(:,2)=Particles.Data(:,UniformPick,t-1);

            if strcmp(ModelParam.setup.example_name, 'Septier16')
                W=1./gamrnd(ModelParam.StateDegreeFreedom/2,1/(ModelParam.StateDegreeFreedom/2));
                Chosen.Data(:,1)=ModelParam.TransitionMatrix*Chosen.Data(:,2)+W*ModelParam.StateSkewness+sqrt(W)*ModelParam.StateCovarianceSR*randn(ModelParam.Dimension,1);

                Chosen.LogLikelihood=ComputationLogLikelihoodv1(Observation(:,t),ModelParam.ObservationTransition*Chosen.Data(:,1),ModelParam);
            else
                Chosen.Data(:,1)=ModelParam.propparams.propagatefcn(Chosen.Data(:,2),ModelParam.propparams);    
                Chosen.LogLikelihood=ModelParam.likeparams.llh(Chosen.Data(:,1),Observation(:,t),ModelParam.likeparams);
            end
        
            
        else % if t~=1 and j~=1
            
            
            RandomVariableWhatStepToDo=rand;
            if Algo.BothJointDraw_RefinementAtEachIteration==1 || RandomVariableWhatStepToDo<Algo.ProbaJointDraw % JOINT DRAW
                Particles.Analysis.NoJointDraw=Particles.Analysis.NoJointDraw+1;
                
                
                if strcmp(ModelParam.setup.example_name, 'Septier16')&&(strcmp(Algo.SamplingTechnique,'Optimal') && strcmp(ModelParam.ModelState,'Normal') && strcmp(ModelParam.ModelObservation,'Normal'))
                    if t==1
                        Candidate.Data(:,2)=zeros(ModelParam.Dimension,1);
                        Candidate.Data(:,1)=ProposalMean+(ProposalCovSR)*randn(ModelParam.Dimension,1);
                    else
                        
                        
                        UniformPick=randsample(1:Algo.NoParticles,1,true,exp(LogMarginalLikelihoodOptimal));
                        
                        Candidate.Data(:,2)=Particles.Data(:,UniformPick,t-1);

                        Candidate.Data(:,1)=ProposalMean(:,UniformPick)+(ProposalCovSR)*randn(ModelParam.Dimension,1);                        
                    end
                    
                    AcceptanceRatio=1;
                else                
                    if t==1
                        Candidate.Data(:,2)=zeros(ModelParam.Dimension,1);                    
                        Candidate.Data(:,1)=ModelParam.propparams.propagatefcn(ModelParam.InitialMean,ModelParam.propparams);
                    else

                        UniformPick=ceil(Algo.NoParticles*rand);
                        Candidate.Data(:,2)=Particles.Data(:,UniformPick,t-1);

                        if strcmp(ModelParam.setup.example_name, 'Septier16')
                                W=1./gamrnd(ModelParam.StateDegreeFreedom/2,1/(ModelParam.StateDegreeFreedom/2));
                                Candidate.Data(:,1)=ModelParam.TransitionMatrix*Candidate.Data(:,2)+W*ModelParam.StateSkewness+sqrt(W)*ModelParam.StateCovarianceSR*randn(ModelParam.Dimension,1);
                    
                        else
                            Candidate.Data(:,1)=ModelParam.propparams.propagatefcn(Candidate.Data(:,2),ModelParam.propparams);
                        end
                    end

                    Candidate.LogLikelihood=ModelParam.likeparams.llh(Candidate.Data(:,1),Observation(:,t),ModelParam.likeparams);

                    AcceptanceRatio=min([exp(Candidate.LogLikelihood-Chosen.LogLikelihood) 1]);
                end
                
                if rand<AcceptanceRatio
                    
                    Chosen=Candidate;
                    Particles.Analysis.AcceptationJointDraw=Particles.Analysis.AcceptationJointDraw+1;
                    
                end
                
                
                
            %else % REFINEMENT STEP PERFORMED WITH PROBA 1-Algo.ProbaJointDraw
            end
            if (Algo.BothJointDraw_RefinementAtEachIteration==1 || RandomVariableWhatStepToDo>=Algo.ProbaJointDraw) && strcmp(Algo.SamplingTechnique,'Optimal')==0
                
                if t>1 % Selection of Previous Term t-1 given t
                    Particles.Analysis.NoPreviousTerm=Particles.Analysis.NoPreviousTerm+1;
                    
                    if strcmp(ModelParam.setup.example_name, 'Septier16')
                        CurrentMean=ModelParam.TransitionMatrix*Chosen.Data(:,2);
                    else
                        CurrentMean=ModelParam.propparams.propagatefcn(Chosen.Data(:,2),propparams_no_noise);
                    end
                    
                    UniformPick=ceil(Algo.NoParticles*rand);
                    Candidate.Data(:,2)=Particles.Data(:,UniformPick,t-1);
                    
                    if strcmp(ModelParam.setup.example_name, 'Septier16')
                        CandidateMean=ModelParam.TransitionMatrix*Candidate.Data(:,2);%,ModelParam);
                    else
                        CandidateMean=ModelParam.propparams.propagatefcn(Candidate.Data(:,2),propparams_no_noise);%,ModelParam);
                    end

                    if strcmp(ModelParam.setup.example_name, 'Septier16')
                        CandidateLogPrior=ComputationLogPrior(Chosen.Data(:,1),CandidateMean,ModelParam);
                        CurrentLogPrior=ComputationLogPrior(Chosen.Data(:,1),CurrentMean,ModelParam);
                    else
                        vg_candidate.xp = Chosen.Data(:,1);
                        vg_candidate.xp_prop_deterministic = CandidateMean;
                        CandidateLogPrior = log_process_density(vg_candidate,ModelParam);
                        vg_chosen.xp = Chosen.Data(:,1);
                        vg_chosen.xp_prop_deterministic = CurrentMean;
                        CurrentLogPrior = log_process_density(vg_chosen,ModelParam);
                    end
       
                    AcceptanceRatio=min([1 exp(CandidateLogPrior-CurrentLogPrior)]);
                    if rand<AcceptanceRatio
                        Chosen.Data(:,2)=Candidate.Data(:,2);
                        Particles.Analysis.AcceptationPreviousTerm=Particles.Analysis.AcceptationPreviousTerm+1;
                        
                    end
                    
                end                
                
                if Algo.BlockSize==ModelParam.Dimension;%No need to do random permutation
                    randpermStateDimension=1:ModelParam.Dimension;%randperm(ModelParam.Dimension);%1:ModelParam.Dimension;%randperm(ModelParam.Dimension);
                else
                    randpermStateDimension=randperm(ModelParam.Dimension);
                end
                 

                for iii=1:NoRefiningSteps
                    Particles.Analysis.NoRefinement=Particles.Analysis.NoRefinement+1;
                    
                    Candidate=Chosen;
                    
%                     
%                     CurrentCov=ModelParam.StateCovariance;
%                     CurrentSkewness=ModelParam.StateSkewness;
                    
                    IndexRefining=randpermStateDimension((1:Algo.BlockSize)+(iii-1)*Algo.BlockSize);
                    
                    if t==1
                        CurrentMean=ModelParam.InitialMean;
                        [MatrixTransformation]=TransformationParametersBlockSampling(ModelParam.Dimension,iii,randpermStateDimension,Algo.BlockSize);%CurrentMean,ModelParam.StateCovariance,ModelParam.StateSkewness);
                    else
                        if strcmp(ModelParam.setup.example_name, 'Septier16')
                            CurrentMean=ModelParam.TransitionMatrix*Candidate.Data(:,2);                                              
                        else
                            CurrentMean=ModelParam.propparams.propagatefcn(Candidate.Data(:,2),propparams_no_noise);
                        end
                        [MatrixTransformation]=TransformationParametersBlockSampling(ModelParam.Dimension,iii,randpermStateDimension,Algo.BlockSize);%CurrentMean,ModelParam.StateCovariance,ModelParam.StateSkewness);                        
                    end
                    
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % CHOICE OF THE DIFFERENT MCMC KERNEL
                    % However, only the SmHMC kernel is incorporated in this version.
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ~strcmp(Algo.SamplingTechnique,'SmHMC') && ~strcmp(ModelParam.setup.example_name, 'Septier16')
                        error('Codes only modified for the SmHMC kernel')
                    end

                    %%%%%%%%%%%%%%%%%%
                    % computation of the parameters of the conditional  prior
                    if Algo.BlockSize==ModelParam.Dimension
                        CondMean=CurrentMean;
                        CondCov=ModelParam.StateCovariance;
                        RearrangedCurrentState=Chosen.Data(:,1);
                        InvCondCov=ModelParam.StateCovarianceInv;
                    else
                        [CondMean,CondCov,RearrangedCurrentState]=ComputationParameterConditionalNormalPrior(MatrixTransformation,Chosen.Data(:,1),CurrentMean,ModelParam.StateCovariance,Algo.BlockSize);

                        InvCondCov=inv(CondCov);
                    end

                    %%%%%%%%%%%%%%%%%%%%%%%%%%
                    % Compute Hessian to draw Momentum variables
                    [NegHessian]=ComputationNegHessian(Observation(:,t),MatrixTransformation,Algo.BlockSize,CondMean,InvCondCov,RearrangedCurrentState,ModelParam);

                    InvNegHessian=inv(NegHessian);
                    SRNegHessian=real(sqrtm(NegHessian));

                    %%%%%%%%%%%%%%%%%%%%%%%%%%
                    % Draw auxiliary variable

                    Candidate.AuxVarHMC(IndexRefining,1)=SRNegHessian(1:Algo.BlockSize,1:Algo.BlockSize)*randn(Algo.BlockSize,1);
                    Chosen.AuxVarHMC(IndexRefining,1)=Candidate.AuxVarHMC(IndexRefining,1); % Accept this move - its a Gibbs move !! 

                    %%%%%%%%%%%%%%%%%%%%%%%%%%
                    % Perform either a Leapfrog or Generalized Leapfrog
                    % Depending on the model
                    if Algo.GeneralizedLeapfrogRequired==0
                        %%%%%%%%%%%%%%%%%%
                        % Perform the Leapfrog
                        [ConditionalSample,CondAuxVarHMC]=LeapfrogForHMC(Candidate.AuxVarHMC(IndexRefining,1),Chosen.Data(IndexRefining,1),Observation(:,t),MatrixTransformation,CurrentMean,ModelParam,Algo,IndexRefining,CondMean,InvCondCov,InvNegHessian);

                        InvNegHessianCandidate=InvNegHessian;
                        NegHessianCandidate=NegHessian;
                    else
                        %%%%%%%%%%%%%%%%%%
                        % Perform the Generalized Leapfrog
                        [ConditionalSample,CondAuxVarHMC,InvNegHessianCandidate,NegHessianCandidate]=GeneralizedLeapfrogFormHMC(Candidate.AuxVarHMC(IndexRefining,1),Chosen.Data(IndexRefining,1),Observation(:,t),MatrixTransformation,CurrentMean,ModelParam,Algo,IndexRefining,CondMean,InvCondCov);
                    end

                    Candidate.Data(IndexRefining,1)=ConditionalSample;
                    Candidate.AuxVarHMC(IndexRefining,1)=CondAuxVarHMC;

                    %%%%%%%%%%%%%%%%%%
                    % Computaiton of the prior                       

                    switch ModelParam.setup.example_name
                        case 'Septier16'
                            CandidateLogPrior=ComputationLogPrior(Candidate.Data(:,1),CurrentMean,ModelParam);
                            ChosenLogPrior=ComputationLogPrior(Chosen.Data(:,1),CurrentMean,ModelParam);
                        case 'Acoustic'
                            vg_candidate.xp = Candidate.Data(:,1);
                            vg_candidate.xp_prop_deterministic = CurrentMean;
                            CandidateLogPrior = log_process_density(vg_candidate,ModelParam);
                            vg_chosen.xp = Chosen.Data(:,1);
                            vg_chosen.xp_prop_deterministic = CurrentMean;
                            ChosenLogPrior = log_process_density(vg_chosen,ModelParam);
                    end
                   %%%%%%%%%%%%%%%%%%
                    % Computaiton of the target of the momentum
                    % variables to be included in the acceptance ratio
                    % It's not a proposal so the negative sign !!
                    CandidateLogProposal=-ComputationLogNormal(Candidate.AuxVarHMC(IndexRefining,1),zeros(Algo.BlockSize,1),InvNegHessianCandidate,NegHessianCandidate);
                    ChosenLogProposal=-ComputationLogNormal(Chosen.AuxVarHMC(IndexRefining,1),zeros(Algo.BlockSize,1),InvNegHessian,NegHessian);

                    %%               
                    
                    if Algo.DisplayProposalCandidate
                        %%%%%%%%%%%%%%%%%%
                        % Display Proposal and Current Value MC

                        figure(99);clf;plot(Chosen.Data(:,1));hold on;plot(Candidate.Data(:,1),'g');hold on;plot(State(:,t),'r')
                        hold on;plot(Observation(:,t),'k')
                        axis([1 ModelParam.Dimension 0 max(State(:,t))+1])
                        drawnow;
                    end

                    

                    %%%%%%%%%%%%%%%%%%
                    % Computation of the Likelihood for the Proposed value
                    
                    
                    if strcmp(ModelParam.setup.example_name, 'Septier16')
                        Candidate.LogLikelihood=ComputationLogLikelihoodv1(Observation(:,t),ModelParam.ObservationTransition*Candidate.Data(:,1),ModelParam);
                    else
                        Candidate.LogLikelihood=ModelParam.likeparams.llh(Candidate.Data(:,1),Observation(:,t),ModelParam.likeparams);
                    end       
            
                    
                    %%%%%%%%%%%%%%%%%%
                    % Computation Acceptance Ratio
                    AcceptanceRatio=min([exp(Candidate.LogLikelihood+CandidateLogPrior-CandidateLogProposal+ChosenLogProposal-Chosen.LogLikelihood-ChosenLogPrior) 1]);
                    
                    
                    

                    if sum(isnan(Candidate.Data(:,1)))>0
                        AcceptanceRatio=0;
                    end
                    
                    

                
                    if rand<AcceptanceRatio
                    
                        Chosen=Candidate;
                        Particles.Analysis.AcceptationRefinement=Particles.Analysis.AcceptationRefinement+1;
                        
                    
                    end                    
                    

                                    
                        
                end  
                        
         
                
                
            end
            
        end
            
        %%%%%%%%%%%%%%%%%%
        % Saved As Particles for next iteration after BurnIn
        %
        if j>Algo.NoBurnIn && mod(j-Algo.NoBurnIn,Algo.Thining)==0
            Particles.Data(:,NumParticles,t)=Chosen.Data(:,1);
            NumParticles=NumParticles+1;            
        end        
    end

     % Computation of the posterior mean
    Particles.Mean(:,t)=mean(Particles.Data(:,:,t),2);
                
    % Computation of the Covariance    
    Particles.Cov(:,:,t)=zeros(ModelParam.Dimension);
    for iCov=1:Algo.NoParticles
        Particles.Cov(:,:,t)=Particles.Cov(:,:,t)+(1/Algo.NoParticles)*(Particles.Data(:,iCov,t)-Particles.Mean(:,t))*(Particles.Data(:,iCov,t)-Particles.Mean(:,t))';
    end
           
    if ModelParam.setup.doplot
        pause(0.1)
        vg.xp = Particles.Data(:,:,t);
        vg.xp_m = Particles.Mean(:,t);
        ModelParam.setup.plotfcn(vg,ModelParam,zeros(size(vg.xp)),t,'After SmHMC');
    end 
                
                
end   
