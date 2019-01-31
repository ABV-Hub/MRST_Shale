%% Case 1 Benchmark with CMG GEM
% In this example, we will demonstrate how one can easily extend the
% compressible single-phase pressure solver to include the effect of
% pressure-dependent viscosity using either arithmetic averaging of the
% viscosity or harmonic averaging of the fluid mobility.
% DataFolder: '\examples\Benchmark_CMG\'
clear;
close all;
%PathConfigure;
% mrstModule add hfm;             % hybrid fracture module
mrstModule add ad-core ad-props mrst-gui compositional
%% Define geometric quantitites
% Create explicit fracture grid with Log LGR
physdim = [1990*ft 1990*ft 150*ft];

%Define fracture geometry
NumFracs=1;
Frac_Spacing=500*ft;
Frac_halfLength=350*ft;
Frac_height=150*ft; %Thickness of reservoir
Frac_StartXY=[physdim(1)/2 physdim(2)/2-Frac_halfLength];

[fl,xy_wells]=createMultiStageFracs(NumFracs,Frac_Spacing,...
    Frac_halfLength,Frac_StartXY);

%% Define geometric quantitites
% Create explicit fracture grid with Log LGR
G = ExplicitFracGrid(physdim,...
    NumFracs,Frac_Spacing,Frac_halfLength,Frac_StartXY,...
    'NX_FracRefine',100,...
    'NX_OutRefine',15,...
    'NY_FracRefine',15,...
    'NY_OutRefine',10,...
    'FracCellSize',0.01*ft,...
    'FracCellSize_Y',0.01*ft);
G = computeGeometry(G);

[NX,NY]=deal(G.cartDims(1),G.cartDims(2));

%Plot Grid
% plotGrid(G,'FaceAlpha',1.0,'EdgeAlpha',0.4), view(2), axis equal tight;

%% Define rock properties
[poro_rock,poro_frac]=deal(0.07,1.0);
[perm_rock,perm_frac]=deal(0.0005*milli*darcy,0.5*darcy);


perm=repmat(perm_rock,NX,NY);
perm(G.FracCell.I,G.FracCell.J)=perm_frac;
poro=repmat(poro_rock,NX,NY);
poro(G.FracCell.I,G.FracCell.J)=poro_frac;

rock = makeRock(G, perm(:), poro(:));

%% Compositional shale gas fluid properties
% Name of problem and pressure range
casename = 'onlymethane';
pwf = 500*psia;
p_init = 5000*psia;

% [fluid]=setShaleGasFluid_Case1(G,rock);
% 
% %% Define shale gas flow model
% model = WaterModelG(G,rock,fluid);

%% Assume constant BHP horizontal well
IJ_wells = markCellbyXY(xy_wells,G);
cellInx = sub2ind(G.cartDims, IJ_wells(:,1), IJ_wells(:,2));
% W = addWell([], G, rock, cellInx,'Dir', 'x','Radius', 0.25*ft, ...
%         'Type', 'bhp', 'Val', 500*psia,'Comp_i',1);

W = [];
% Producer
W = addWell(W, G, rock, cellInx, 'Dir', 'x','Radius', 0.25*ft, ...
    'comp_i', [1], 'Val', 500*psia, 'sign', -1, 'Type', 'bhp');    

%% Impose initial pressure equilibrium
p0=5000*psia;
% state  = initResSol(G, p0, 0);%0-single phase model

%% Set up model and initial state
nkr = 2;
[fluid, info] = getCompositionalFluidCase(casename);
flowfluid = initSimpleADIFluid('n', [nkr, nkr, nkr], 'rho', [1000, 800, 10]);

gravity reset off
model = NaturalVariablesCompositionalModel(G, rock, flowfluid, fluid, 'water', false);
% model = OverallCompositionCompositionalModel(G, rock, flowfluid, fluid, 'water', false);

ncomp = fluid.getNumberOfComponents();
s0 = [1];
TinK = 327.594;
state0 = initCompositionalState(G, p0, TinK, s0, info.initial, model.EOSModel);

for i = 1:numel(W)
    W(i).components = info.initial;
end
%% Set up schedule and simulate the problem
%time step has to be setup with wells
M = csvread('CMG_timestep2.csv',1);
dt_list=M(:,1)*day;
time_list=cumsum(convertTo(dt_list,day));

schedule = simpleSchedule(dt_list, 'W', W);

%% Run simulations
[ws_comp, states_comp, report_comp] = simulateScheduleAD(state0, model, schedule);
%% Plot all the results
lf = get(0, 'DefaultFigurePosition');
h = figure('Position', lf + [0, -200, 350, 200]);
nm = ceil(ncomp/2);
v = [-30, 60];
for step = 1:numel(states_comp)
    figure(h); clf
    state = states_comp{step};
    for i = 1:ncomp
        subplot(nm, 3, i);
        plotCellData(G, state.components(:, i), 'EdgeColor', 'none');
        view(v);
        title(fluid.names{i})
        caxis([0, 1])
    end
    subplot(nm, 3, ncomp + 1);
    plotCellData(G, state.pressure, 'EdgeColor', 'none');
    view(v);
    title('Pressure')
    
%     subplot(nm, 3, ncomp + 2);
%     plotCellData(G, state.s(:, 1), 'EdgeColor', 'none');
%     view(v);
%     title('sO')
    
%     subplot(nm, 3, ncomp + 3);
%     plotCellData(G, state.s(:, 2), 'EdgeColor', 'none');
%     view(v);
%     title('sG')
%     drawnow
end
%% Plot the results in the interactive viewer
figure(6); clf;
plotToolbar(G, states_comp)
view(v);
axis tight


figure(7);
plotWellSols(ws_comp,cumsum(schedule.step.val))
tinDays = cumsum(schedule.step.val)/86400;




%---------------------------------------------------------------------------
% Black oil model
%---------------------------------------------------------------------------
%% Black-oil shale gas fluid properties
[fluid]=setShaleGasFluid_Case1(G,rock);

%% Define shale gas flow model
model = WaterModelG(G,rock,fluid);

schedule = simpleSchedule(dt_list, 'W', W);

%% Impose initial pressure equilibrium
state0  = initResSol(G, p0, 0);%0-single phase model
[ws_BO, states_BO, report_BO] = simulateScheduleAD(state0, model, schedule);



names = {'Compositional', 'BlackOil'};

ws = {ws_comp, ws_BO};
shortname = {'comp', 'BO'};
plotWellSols(ws_comp, cumsum(schedule.step.val))
plotWellSols(ws_BO, cumsum(schedule.step.val))


% plotWellSols(ws, cumsum(schedule.step.val), 'datasetnames', names)

% 
% plotToolbar(G, states);
% axis equal tight off
% daspect([1 1 0.2])
% view(85, 20);
% plotWell(G, W);
% title(names{1});
% colorbar('horiz')
% 
% figure; plotToolbar(G, states_ms);
% axis equal tight off
% daspect([1 1 0.2])
% view(85, 20);
% plotWell(G, W);
% title(names{2});
% colorbar('horiz')


if isfield(fluid,'mG_ad')
    data_file='CMG_PRO_Langmuir.csv';
else
    data_file='CMG_PRO_base.csv';
end
data_file='LGR250.csv';



%plotWellSols({ws},dt_list, 'field','qWs');
figure(3);
PlotEDFMGasRate(time_list,ws_BO, ...
    'Reference_data',data_file,...
    'YUnit', meter^3/day,...
    'XUnit', day,...
    'Xlim',[1e-4 1e4],...
    'CumPlot',1,...
    'LogLog',1);

figure(4);
PlotEDFMPresSurf(fl,G,states,numel(time_list))


PV = sum(G.cells.volumes .* rock.poro)/(ft^3)  %41582 Mrcf
% Bgi = (14.6959/520)*z*TinK/p0;  %rcf/scf
% STOIIP = sum(G.cells.volumes .* rock.poro)/Bgi; %in scm