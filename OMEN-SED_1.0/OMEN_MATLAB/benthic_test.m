%% OMEN-SED 1.1 BENTHIC-MODEL Stand-alone matlab code
% Hülse et al. (2017) GMD
% including the RCM approximation of Pika et al. (2020) GMD

% benthic_test.m
% functions to run OMEN-SED and plot the results

% Command to run the model: 
% benthic_test.run_OMEN: For original 2G model
% benthic_test.run_OMEN_RCM: For RCM approximation
% 1) default sediment-water interface boundary conditions are set as prescribed in default_swi()
% 2) the subroutines for the different properties are called in test_benthic(1,swi):
% 3) results saved in res and are plotted with plot_column()

classdef benthic_test
    % test cases for benthic layer model
    
    properties
    end
    
    methods(Static)
        
        function swi = default_swi()
            % set default SWI conditions
            
            format longEng
            
            bsd = benthic_main();
            %bottom water concentrations
            swi.T = 8.0;                                        % temperature (degree C)
            
            % for 2G-model
            swi.C01_nonbio= 1.0*1e-2/12*bsd.rho_sed;            % TOC concentration at SWI (wt%) -> (mol/cm^3 bulk phase)
            swi.C02_nonbio= 1.0*1e-2/12*bsd.rho_sed;            % TOC concentration at SWI (wt%) -> (mol/cm^3 bulk phase)
            swi.Fnonbio1 = swi.C01_nonbio*(1-bsd.por)*bsd.w;    % calculate flux [mol/(cm2 yr)] according non-bioturbated flux
            swi.Fnonbio2 = swi.C02_nonbio*(1-bsd.por)*bsd.w;    % calculate flux [mol/(cm2 yr)] according non-bioturbated flux
            swi.C01 = swi.C01_nonbio;                           % resulting bioturbated SWI-concentration, to be calculated in benthic_zTOC.m
            swi.C02 = swi.C02_nonbio;                           % resulting bioturbated SWI-concentration, to be calculated in benthic_zTOC.m           
            
            % for nG-model
            swi.nG = 100;
            swi.p_a = 10;
            swi.p_nu = 0.222;
            swi.C0 = 0.5 * 1e-2/12*bsd.rho_sed;                 % TOC concentration at SWI (wt%) -> (mol/cm^3 bulk phase)


            swi.O20=300.0E-009;                                 % O2  concentration at SWI (mol/cm^3)
            swi.NO30=40.0e-9;                                   % NO3 concentration at SWI (mol/cm^3)
            swi.Nitrogen=true;                                  % calculate N (true/false)
            swi.NH40=10.0e-9;                                 	% NH4 concentration at SWI (mol/cm^3)
            swi.SO40=2.8E-005;                                	% SO4 concentration at SWI (mol/cm^3)
            swi.H2S0=0.0;                                       % H2S concentration at SWI (mol/cm^3)
            swi.PO40=40.0e-9;                                   % PO4 concentration at SWI (mol/cm^3)
            swi.Mflux0=365*0.2e-10*1/(1-bsd.por)*1/bsd.w;       % actually CONCENTRATION of M at the sediment [mol/cm3] : from flux input  365*0.2e-10 (mol/(cm2*yr))
            swi.DIC0=2.4E-006;                                 	% DIC concentration at SWI (mol/cm^3)
            swi.ALK0=2.4E-006;                                 	% ALK concentration at SWI (mol/cm^3)
            swi.S0=35;                                         	% Salinity at SWI (not used at the moment)
            swi.plot_PO4_DIC_ALK=true;
        end
        
        function run_OMEN()
            % run OMEN-SED with default SWI conditions as in default_swi()
            clear
            tic;
            swi=benthic_test.default_swi()
            swi.TwoG_OM_model = true;
            %            % set date-time
            %            str_date = datestr(now,'ddmmyy_HH_MM_SS');
            res=benthic_test.test_benthic(1,swi);
            toc;
            benthic_test.plot_column(res, false, swi, 'FULL_OMEN')
            
            % calculate depth integrated OM degradation rates
            Cox_rate.Cox_total = res.zTOC.calcReac(0.0, res.bsd.zinf, 1, 1, res.bsd, swi, res);
            Cox_rate.Cox_aerobic = res.zTOC.calcReac(0.0, res.zox, 1, 1, res.bsd, swi, res);
            if(swi.Nitrogen)
                Cox_rate.Cox_denitr = res.zTOC.calcReac(res.zox, res.zno3, 1, 1, res.bsd, swi, res);
            end
            Cox_rate.Cox_sulfred = res.zTOC.calcReac(res.zno3, res.bsd.zinf, 1, 1, res.bsd, swi, res)
            
            % calculate mean OM concentration in upper x cm
            [C_10, C1_10, C2_10] = res.zTOC.calcC( 10, res.bsd, res.swi, res);
            OM_10=C_10* 100*12/res.bsd.rho_sed
            x = 10;
            Mean_OM = 1/x * 100*12/res.bsd.rho_sed*res.zTOC.calcOM(0.0, x, 1, 1, res.bsd, swi, res)
        end
        
        function res = run_OMEN_RCM()
            % run OMEN-SED with default SWI conditions as in default_swi()
            clear
            swi = benthic_test.default_swi();
            swi.TwoG_OM_model = false;

            res=benthic_test.test_benthic(1,swi);
            % set date-time or string going into plot function
            str_date = [num2str(res.swi.nG) 'G_a=' num2str(res.swi.p_a) '_nu=' num2str(res.swi.p_nu) '_O20_' num2str(res.swi.O20)];
            benthic_test.plot_column(res, false, swi, str_date)
            benthic_test.plot_TOC(res, false, swi, str_date)
            % calculate depth integrated OM degradation rates
            swi.C0i = res.swi.C0i;
            Cox_rate.Cox_total = res.zTOC_RCM.calcReac(0.0, res.bsd.zinf, 1, res.bsd, swi, res);
            Cox_rate.Cox_aerobic = res.zTOC_RCM.calcReac(0.0, res.zox, 1, res.bsd, swi, res);
            if(swi.Nitrogen)
                Cox_rate.Cox_denitr = res.zTOC_RCM.calcReac(res.zox, res.zno3, 1, res.bsd, swi, res);
            end
            % calculate mean OM concentration in upper x cm
            [C_10, C1_11] = res.zTOC_RCM.calcC( 10, res.bsd, res.swi, res);
            OM_10=C_10* 100*12/res.bsd.rho_sed
            x = 10;
            Mean_OM = 1/x * 100*12/res.bsd.rho_sed*res.zTOC_RCM.calcOM(0.0, x, 1, res.bsd, swi, res)
        end
        
        function res = test_benthic( ncl, swi )
            loc_BW_O2_anoxia = 5.0e-9;       	% set to 5.0 nanomol/cm^3
            if nargin < 1
                ncl = 1;
            end
            
            res.bsd = benthic_main(ncl);
            res.bsd.usescalarcode = ncl==1;
            
            
            if nargin < 2 || isempty(swi)
                swi = benthic_test.default_swi();
            end
            
            if ncl > 1  % set up O2 gradient for testing
                O20 = swi.O20;
                for i = 1:ncl
                    swi.O20(i) = 10*(i-1)/(ncl-1)*O20;
                end
            end
            
            res.swi = swi;
            
            % calculate
            if(swi.TwoG_OM_model)
                res.zTOC = benthic_zTOC(res.bsd);
            else
                res.zTOC_RCM = benthic_zTOC_RCM(res.bsd);
            end
            res.zO2 = benthic_zO2(res.bsd, res.swi);
            res.zNO3 = benthic_zNO3(res.bsd, res.swi);
            res.zSO4 = benthic_zSO4(res.bsd, res.swi);
            res.zNH4 = benthic_zNH4(res.bsd, res.swi);
            res.zH2S = benthic_zH2S(res.bsd, res.swi);
            res.zPO4_M = benthic_zPO4_M(res.bsd, res.swi);
            res.zDIC = benthic_zDIC(res.bsd, res.swi);
            res.zALK = benthic_zALK(res.bsd, res.swi);
            
            tic;
            if(swi.TwoG_OM_model)
                res = res.zTOC.calc(res.bsd,res.swi, res);
                O2_demand_flux = -(res.swi.Fnonbio1+res.swi.Fnonbio2)*res.bsd.OC/((1-res.bsd.por)./res.bsd.por)
            else
                % Adding into on RCM for MultiG approach
                [res.zTOC_RCM.k, res.swi.C0i, res.swi.Fnonbioi] = benthic_test.RCM(res.bsd, res.swi);
                res = res.zTOC_RCM.calc(res.bsd,res.swi, res);
                O2_demand_flux = -(sum(res.swi.Fnonbioi))*res.bsd.OC/((1-res.bsd.por)./res.bsd.por);
            end
            
            
            % %     change zbio and gammaH2S depending on BW oxygenation:
            % %             if(res.swi.O20<=loc_BW_O2_anoxia)   % anoxic sediments?
            % %                 bsd.zbio = 0.01;        % decrease bioturbation depth
            % %                 bsd.gammaH2S = 0.95;    % fraction of H2S that is oxidised in anoxic sediments
            % %             end
            
            if(res.swi.O20<=0.0)
                res.zox=0.0;
                res.flxzox = 0.0;
                res.conczox = 0.0;
                res.flxswiO2=0.0;
                res.zxf=0.0;
            else
                res = res.zO2.calc(res.bsd, res.swi, res);
            end
            if(swi.Nitrogen)
                res = res.zNO3.calc(res.bsd, res.swi, res);
            else
                res.zno3=res.zox;
                %                res.zso4=res.zox;   % for test-case with just TOC & O2
            end
            res = res.zSO4.calc(res.bsd, res.swi, res);
            if(swi.Nitrogen)
                res = res.zNH4.calc(res.bsd, res.swi, res);
            end
            res = res.zH2S.calc(res.bsd, res.swi, res);
            res = res.zPO4_M.calc(res.bsd, res.swi, res);
            res = res.zDIC.calc(res.bsd, res.swi, res);
            res = res.zALK.calc(res.bsd, res.swi, res);
            toc;
            
            %%%%% WRITE OUTPUT:
            answ = res
            if(swi.TwoG_OM_model)
                [Cinf, C1inf, C2inf] = res.zTOC.calcC( 100, res.bsd, res.swi, res);
                [Cswi, C1swi, C2swi] = res.zTOC.calcC( 0, res.bsd, res.swi, res);
                fprintf('frac1 concentration at zinf %g \n',  C1inf);
                fprintf('frac2 concentration at zinf %g \n',  C2inf);
                fprintf('both concentration at zinf %g \n',  Cinf);
                fprintf('frac1 concentration at swi %g \n',  C1swi);
                fprintf('frac2 concentration at swi %g \n',  C2swi);
                fprintf('both concentration at swi %g \n',  Cswi);
                
                fprintf('sed preservation of POC %g \n',  Cinf/Cswi);
                %             %%% WRITE EXACT FLUX
                %             FO2_exact=res.zO2.calcFO2_exact(res.zox,res.bsd, res.swi, res);
                %             fprintf('exact F_O2 flux (mol cm^{-2} yr^{-1}) %g \n',  FO2_exact);
            else
                [Cinf, C1inf] = res.zTOC_RCM.calcC( 100, res.bsd, res.swi, res);
                [Cswi, C1swi] = res.zTOC_RCM.calcC( 0, res.bsd, res.swi, res);
                fprintf('both concentration at zinf %g \n',  Cinf);
                fprintf('both concentration at swi %g \n',  Cswi);
                
                fprintf('sed preservation of POC %g \n',  Cinf/Cswi);
                %             %%% WRITE EXACT FLUX
                %             FO2_exact=res.zO2.calcFO2_exact(res.zox,res.bsd, res.swi, res);
                %             fprintf('exact flxswiO2 flux (mol cm^{-2} yr^{-1}) %g \n',  FO2_exact);
                
            end
        end
        
        
        function plot_column(res, debug, swi, str_date)
            % plot single sediment column vs depth
            
            set(0,'defaultLineLineWidth', 2)
            set(0,'DefaultAxesFontSize',12)
            
            bsd = res.bsd;
            zgrid = 0:0.1:bsd.zinf;
            
            
            % CONCENTRATIONS WITHOUT PO4
            set(0,'defaultLineLineWidth', 2)
            set(0,'DefaultAxesFontSize',12)
            
            % Nitrogen included?
            if(swi.Nitrogen)
                figure;
                % TOC
                if(swi.TwoG_OM_model)
                    subplot(3,2,1)
                    for i=1:length(zgrid)
                        [C(i), C1(i), C2(i)] = res.zTOC.calcC( zgrid(i), bsd, res.swi, res);
                        [Cflx(i), C1flx(i), C2flx(i)] = res.zTOC.calcCflx( zgrid(i), bsd, res.swi, res);
                    end
                    
                    %%% TOC wt %
                    plot(100*C1*12/bsd.rho_sed, -zgrid, 'b')
                    hold on
                    plot(100*C2*12/bsd.rho_sed, -zgrid, 'g')
                    plot(100*C*12/bsd.rho_sed, -zgrid, 'k')
                    t=xlim;         % to draw penetration depths the correct lengths
                    plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                    plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                    plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                    plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                    
                    %            plot([0,(res.swi.C01+res.swi.C02)*12/bsd.rho_sed ], [-bsd.zbio,-bsd.zbio], 'k--')
                    hold off
                    %                ylim([-50 0.0])
                    xlabel ('TOC (wt%)')
                    ylabel('Depth (cm)')
                    %            title('Total TOC (wt%)')
                else
                    subplot(3,2,1)
                    for i=1:length(zgrid)
                        [C(i), C1(i,:)] = res.zTOC_RCM.calcC( zgrid(i), bsd, res.swi, res);
                        [Cflx(i), C1flx(i,:)] = res.zTOC_RCM.calcCflx( zgrid(i), bsd, res.swi, res);
                    end
                    %                 color = parula(swi.nG);
                    %                 for G = 1:swi.nG
                    %                     plot(100*C1(:,G)*12/bsd.rho_sed, -zgrid,'Color',color(G,:))
                    %                     hold on
                    %                 end
                    % Plot sum (TOC)
                    plot(100*C*12/bsd.rho_sed, -zgrid, 'b')
                    hold on
                    t=xlim;         % to draw penetration depths the correct lengths
                    plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                    plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                    plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                    plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                    
                    hold off
                    xlabel ('TOC (wt%)')
                    ylabel('Depth (cm)')
                    %            title('Total TOC (wt%)')
                    
                end
                
                %%% O2
                if(res.zox>0.0)
                    for i=1:length(zgrid)
                        [O2(i), flxO2(i), flxO2D(i), flxO2adv(i)] = res.zO2.calcO2(zgrid(i), bsd, res.swi, res);
                    end
                else
                    O2(i) = 0.0;
                end
                subplot(3,2,3)
                plot(O2, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                ylim([-20 0.0])
                xlabel ('O_2 (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('O2 (mol/cm^3)')
                
                %%% NO3
                for i=1:length(zgrid)
                    [NO3(i), flxNO3(i)] = res.zNO3.calcNO3(zgrid(i), bsd, res.swi, res);
                end
                subplot(3,2,5)
                plot(NO3, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                ylim([-20 0.0])
                xlabel ('NO_3 (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('NO3 (mol/cm^3)')
                
                %%% NH4
                for i=1:length(zgrid)
                    [NH4(i), flxNH4(i)] = res.zNH4.calcNH4(zgrid(i), bsd, res.swi, res);
                end
                subplot(3,2,4)
                plot(NH4, -zgrid, 'b')
                hold on
                %                xlim([0 1e-7])
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                hold off
                xlabel ('NH_4 (mol/cm^3)')
                %                ylabel('Depth (cm)')
                %            title ('NH4 (mol/cm^3)')
                
                %%% SO4
                subplot(3,2,2)
                for i=1:length(zgrid)
                    [SO4(i), flxSO4(i)] = res.zSO4.calcSO4(zgrid(i), bsd, res.swi, res);
                end
                plot(SO4, -zgrid, 'b')
                hold on
                %                xlim([2.7e-5 swi.SO40])
                %                xlim([2.7e-5 swi.SO40])
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                hold off
                xlabel ('SO_4 (mol/cm^3)')
                %                ylabel('Depth (cm)')
                %            title ('SO4 (mol/cm^3)')
                
                %%% H2S
                subplot(3,2,6)
                for i=1:length(zgrid)
                    [H2S(i), flxH2S(i)] = res.zH2S.calcH2S(zgrid(i), bsd, res.swi, res);
                end
                plot(H2S, -zgrid, 'b')
                hold on
                %                xlim([0 4e-7])
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                xlabel ('H_2S (mol/cm^3)')
                %               ylabel('Depth (cm)')
                %            title ('H2S (mol/cm^3)')
                
                % save Figure
                print('-depsc2', ['0_ALL_PROFILES_' str_date '.eps']);
                
            else % no Nitrogen
                
                figure;
                % TOC
                if(swi.TwoG_OM_model)
                    subplot(2,2,1)
                    for i=1:length(zgrid)
                        [C(i), C1(i), C2(i)] = res.zTOC.calcC( zgrid(i), bsd, res.swi, res);
                        [Cflx(i), C1flx(i), C2flx(i)] = res.zTOC.calcCflx( zgrid(i), bsd, res.swi, res);
                    end
                    %%% TOC wt %
                    plot(100*C1*12/bsd.rho_sed, -zgrid, 'b')
                    hold on
                    plot(100*C2*12/bsd.rho_sed, -zgrid, 'g')
                    plot(100*C*12/bsd.rho_sed, -zgrid, 'k')
                    t=xlim;         % to draw penetration depths the correct lengths
                    plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                    plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                    plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                    plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                    
                    %            plot([0,(res.swi.C01+res.swi.C02)*12/bsd.rho_sed ], [-bsd.zbio,-bsd.zbio], 'k--')
                    hold off
                    xlabel ('TOC (wt%)')
                    ylabel('Depth (cm)')
                    %            title('Total TOC (wt%)')
                else
                    subplot(2,2,1)
                    for i=1:length(zgrid)
                        [C(i), C1(i,:)] = res.zTOC_RCM.calcC( zgrid(i), bsd, res.swi, res);
                        [Cflx(i), C1flx(i,:)] = res.zTOC_RCM.calcCflx( zgrid(i), bsd, res.swi, res);
                    end
                    color = parula(swi.nG);
                    for G = 1:swi.nG
                        plot(100*C1(:,G)*12/bsd.rho_sed, -zgrid,'Color',color(G,:))
                        hold on
                    end
                    % Plot sum (TOC)
                    plot(100*C*12/bsd.rho_sed, -zgrid, ':k')
                    hold on
                    t=xlim;         % to draw penetration depths the correct lengths
                    plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                    plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                    plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                    plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                    
                    hold off
                    xlabel ('TOC (wt%)')
                    ylabel('Depth (cm)')
                    %            title('Total TOC (wt%)')
                    
                end
                
                %%% O2
                for i=1:length(zgrid)
                    [O2(i), flxO2(i), flxO2D(i), flxO2adv(i)] = res.zO2.calcO2(zgrid(i), bsd, res.swi, res);
                end
                subplot(2,2,3)
                plot(O2, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                xlabel ('O_2 (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('O2 (mol/cm^3)')
                
                %%% SO4
                subplot(2,2,2)
                for i=1:length(zgrid)
                    [SO4(i), flxSO4(i)] = res.zSO4.calcSO4(zgrid(i), bsd, res.swi, res);
                end
                plot(SO4, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                hold off
                %            xlim([2.7e-5 swi.SO40])
                xlabel ('SO_4 (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('SO4 (mol/cm^3)')
                
                %%% H2S
                subplot(2,2,4)
                for i=1:length(zgrid)
                    [H2S(i), flxH2S(i)] = res.zH2S.calcH2S(zgrid(i), bsd, res.swi, res);
                end
                plot(H2S, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                xlabel ('H_2S (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('H2S (mol/cm^3)')
                
                
                print('-dpsc2', ['0_PROFILES_' str_date '.eps']);
            end
            
            % Also plot the 2nd figure for PO4, DIC and ALK?
            if(swi.plot_PO4_DIC_ALK)
                figure
                
                %%% PO4
                subplot(3,2,1)
                for i=1:length(zgrid)
                    [PO4(i), flxPO4(i), M(i), flxM(i), e_M(i), f_M(i), p_M(i), q_M(i), g_M(i), dedz_M(i), dfdz_M(i), dpdz_M(i), dqdz_M(i), dgdz_M(i)] = res.zPO4_M.calcPO4_M(zgrid(i), bsd, res.swi, res);
                end
                plot(PO4, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                %          axis([0 1.5*10^(-9) -100 0])
                xlabel ('PO_4 (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('PO_4 (mol/cm^3)')
                
                %%% Fe-bound P (M)
                subplot(3,2,2)
                %for i=1:length(zgrid)
                %    [PO4(i), flxPO4(i), M(i), flxM(i)] = res.zPO4_M.calcPO4_M(zgrid(i), bsd, res.swi, res);
                %end
                plot(M, -zgrid, 'b')
                hold on
                %            plot([0,max(M)], [-bsd.zbio,-bsd.zbio], 'k--')
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                xlabel ('Fe-bound P (mol/cm^3)')
                %            ylabel('Depth (cm)')
                %            title ('Fe-bound P (mol/cm^3)')
                
                %%% DIC
                subplot(3,2,3)
                for i=1:length(zgrid)
                    [DIC(i), flxDIC(i)] = res.zDIC.calcDIC(zgrid(i), bsd, res.swi, res);
                end
                plot(DIC, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                xlabel ('DIC (mol/cm^3)')
                ylabel('Depth (cm)')
                
                %%% ALK
                subplot(3,2,4)
                for i=1:length(zgrid)
                    [ALK(i), flxALK(i)] = res.zALK.calcALK(zgrid(i), bsd, res.swi, res);
                end
                plot(ALK, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                xlabel ('ALK (mol/cm^3)')
                ylabel('Depth (cm)')
                
                
                print('-depsc2', ['0_PO4_PROFILES_' str_date '.eps']);
            end
            
            
            %%% some plots for debugging!
            if debug
                figure
                
                subplot(3,2,1)
                hold on
                plot(e_M, -zgrid, 'b')
                title ('Fe-P - ODE solution')
                
                subplot(3,2,2)
                hold on
                plot(f_M, -zgrid, 'b')
                
                subplot(3,2,3)
                hold on
                plot(p_M, -zgrid, 'b')
                
                subplot(3,2,4)
                hold on
                plot(q_M, -zgrid, 'b')
                
                subplot(3,2,5)
                hold on
                plot(g_M, -zgrid, 'b')
                
                figure
                hold on
                subplot(3,2,1)
                plot(dedz_M, -zgrid, 'b')
                title ('Fe-P - ODE derivations')
                subplot(3,2,2)
                plot(dfdz_M, -zgrid, 'b')
                subplot(3,2,3)
                plot(dpdz_M, -zgrid, 'b')
                subplot(3,2,4)
                plot(dqdz_M, -zgrid, 'b')
                subplot(3,2,5)
                plot(dgdz_M, -zgrid, 'b')
                
                
                %%%%%%%%%%%%%%%%%%%%%
                
                %         H2S
                
                %%%%%%%%%%%%%%%%%%%%%
                figure
                subplot(3,3,2)
                for i=1:length(zgrid)
                    [H2S(i), flxH2S(i), e_H2S(i), dedz_H2S(i), f_H2S(i), dfdz_H2S(i), g_H2S(i), dgdz_H2S(i)] = res.zH2S.calcH2S(zgrid(i), bsd, res.swi, res);
                    % no func. called calcH2S_debug [H2S(i), flxH2S(i), e_H2S(i), dedz_H2S(i), f_H2S(i), dfdz_H2S(i), g_H2S(i), dgdz_H2S(i)] = res.zH2S.calcH2S_debug(zgrid(i), bsd, res.swi, res);
                    
                end
                plot(H2S, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                xlabel ('H_2S (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('H2S (mol/cm^3)')
                
                subplot(3,3,4)
                hold on
                plot(e_H2S, -zgrid, 'b')
                title ('H_2S - ODE solution')
                
                subplot(3,3,5)
                hold on
                plot(f_H2S, -zgrid, 'b')
                
                subplot(3,3,6)
                hold on
                plot(g_H2S, -zgrid, 'b')
                
                subplot(3,3,7)
                hold on
                plot(dedz_H2S, -zgrid, 'b')
                title ('H_2S - ODE derivations')
                
                subplot(3,3,8)
                hold on
                plot(dfdz_H2S, -zgrid, 'b')
                
                subplot(3,3,9)
                hold on
                plot(dgdz_H2S, -zgrid, 'b')
                
                
                
                % CONCENTRATION + Vertical Trransport
                figure;
                % TOC
                if(swi.TwoG_OM_model)
                    subplot(3,4,1)
                    for i=1:length(zgrid)
                        [C(i), C1(i), C2(i)] = res.zTOC.calcC( zgrid(i), bsd, res.swi, res);
                        [Cflx(i), C1flx(i), C2flx(i)] = res.zTOC.calcCflx( zgrid(i), bsd, res.swi, res);
                    end
                    % TOC wt %
                    plot(100*C1*12/bsd.rho_sed, -zgrid, 'b')
                    hold on
                    plot(100*C2*12/bsd.rho_sed, -zgrid, 'g')
                    plot(100*C*12/bsd.rho_sed, -zgrid, 'k')
                    plot([0,(res.swi.C01+res.swi.C02)*12/bsd.rho_sed ], [-bsd.zbio,-bsd.zbio], 'k--')
                    hold off
                    xlabel ('TOC (wt%)')
                    ylabel('Depth (cm)')
                    title('Total TOC (wt%)')
                    % TOC vertical transport flux
                    subplot(3,4,2);
                    plot(C1flx, -zgrid, 'b')
                    hold on
                    plot(C2flx, -zgrid, 'g')
                    plot(Cflx, -zgrid, 'k')
                    xlabel ('TOC trspt (mol cm^{-2}yr^{-1})')
                    ylabel('Depth (cm)')
                    title('TOC vert transport')
                else
                    subplot(3,4,1)
                    for i=1:length(zgrid)
                        [C(i), C1(i,:)] = res.zTOC_RCM.calcC( zgrid(i), bsd, res.swi, res);
                        [Cflx(i), C1flx(i,:)] = res.zTOC_RCM.calcCflx( zgrid(i), bsd, res.swi, res);
                    end
                    color = parula(swi.nG);
                    for G = 1:swi.nG
                        plot(100*C1(:,G)*12/bsd.rho_sed, -zgrid,'Color',color(G,:))
                        hold on
                    end
                    % Plot sum (TOC)
                    plot(100*C*12/bsd.rho_sed, -zgrid, ':k')
                    hold on
                    t=xlim;         % to draw penetration depths the correct lengths
                    plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                    plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                    plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                    plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                    hold off
                    xlabel ('TOC (wt%)')
                    ylabel('Depth (cm)')
                    % TOC vertical transport flux
                    subplot(3,4,2);
                    plot(C1flx, -zgrid, 'b')
                    hold on
                    plot(Cflx, -zgrid, 'k')
                    xlabel ('TOC trspt (mol cm^{-2}yr^{-1})')
                    ylabel('Depth (cm)')
                    title('TOC vert transport')
                    
                end
                
                % O2
                for i=1:length(zgrid)
                    [O2(i), flxO2(i), flxO2D(i), flxO2adv(i)] = res.zO2.calcO2(zgrid(i), bsd, res.swi, res);
                end
                subplot(3,4,3)
                plot(O2, -zgrid, 'b')
                hold on
                plot([0,res.swi.O20], [-bsd.zbio,-bsd.zbio], 'k--')
                xlabel ('O2 (mol/cm^3)')
                ylabel('Depth (cm)')
                title ('O2 (mol/cm^3)')
                subplot(3,4,4);
                plot(flxO2, -zgrid, 'b', flxO2D,-zgrid,'b--',flxO2adv,-zgrid,'c--');%,flxO2D+flxO2adv,-zgrid,'r--');
                legend('tot','diff','adv','diff+adv');
                legend boxoff;
                xlabel ('O2 trsp(mol cm^{-2}yr^{-1})')
                ylabel('Depth (cm)')
                title ('O2 vert transport')
                
                
                for i=1:length(zgrid)
                    [NO3(i), flxNO3(i)] = res.zNO3.calcNO3(zgrid(i), bsd, res.swi, res);
                end
                subplot(3,4,5)
                plot(NO3, -zgrid, 'b')
                hold on
                plot([0,res.swi.NO30], [-bsd.zbio,-bsd.zbio], 'k--')
                xlabel ('NO3 (mol/cm^3)')
                ylabel('Depth (cm)')
                title ('NO3 (mol/cm^3)')
                subplot(3,4,6)
                plot(flxNO3, -zgrid, 'b')
                xlabel ('NO3 trsp(mol cm^{-2}yr^{-1})')
                ylabel('Depth (cm)')
                title ('NO3 vert transport');
                
                
                
                for i=1:length(zgrid)
                    [NH4(i), flxNH4(i)] = res.zNH4.calcNH4(zgrid(i), bsd, res.swi, res);
                end
                subplot(3,4,7)
                plot(NH4, -zgrid, 'b')
                hold on
                plot([0,res.swi.NH40], [-bsd.zbio,-bsd.zbio], 'k--')
                hold off
                xlabel ('NH4 (mol/cm^3)')
                ylabel('Depth (cm)')
                title ('NH4 (mol/cm^3)')
                subplot(3,4,8)
                plot(flxNH4, -zgrid, 'b');
                xlabel ('NH4 trsp(mol cm^{-2}yr^{-1})')
                ylabel('Depth (cm)')
                title ('NH4 vert transport')
                % Till here
                subplot(3,4,9)
                for i=1:length(zgrid)
                    [SO4(i), flxSO4(i)] = res.zSO4.calcSO4(zgrid(i), bsd, res.swi, res);
                end
                plot(SO4, -zgrid, 'b')
                hold on
                plot([0,res.swi.SO40], [-bsd.zbio,-bsd.zbio], 'k--')
                hold off
                %xlim([0 SO40])
                xlabel ('SO4 (mol/cm^3)')
                ylabel('Depth (cm)')
                title ('SO4 (mol/cm^3)')
                subplot(3,4,10)
                plot(flxSO4, -zgrid, 'b');
                xlabel ('SO4 trsp(mol cm^{-2}yr^{-1})')
                ylabel('Depth (cm)')
                title ('SO4 vert transport')
                
                subplot(3,4,11)
                for i=1:length(zgrid)
                    [H2S(i), flxH2S(i)] = res.zH2S.calcH2S(zgrid(i), bsd, res.swi, res);
                end
                plot(H2S, -zgrid, 'b')
                hold on
                plot([0,res.swi.H2S0], [-bsd.zbio,-bsd.zbio], 'k--')
                xlabel ('H2S (mol/cm^3)')
                ylabel('Depth (cm)')
                title ('H2S (mol/cm^3)')
                subplot(3,4,12)
                plot(flxH2S, -zgrid, 'b');
                xlabel ('H2S trsp(mol cm^{-2}yr^{-1})')
                ylabel('Depth (cm)')
                title ('H2S vert transport')
                
                
                if(~swi.TwoG_OM_model)
                    figure;
                    %%% TOC
                    subplot(3,2,1)
                    for i=1:length(zgrid)
                        [C(i), C1(i,:)] = res.zTOC.calcC( zgrid(i), bsd, res.swi, res);
                        [Cflx(i), C1flx(i,:)] = res.zTOC.calcCflx( zgrid(i), bsd, res.swi, res);
                    end
                    color = parula(swi.nG);
                    for G = 1:swi.nG
                        plot(100*C1(:,G)*12/bsd.rho_sed, -zgrid,'Color',color(G,:))
                        hold on
                    end
                    
                    t=xlim;         % to draw penetration depths the correct lengths
                    plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                    plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                    plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
                    plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
                    
                    hold off
                    xlabel ('TOC (wt%)')
                    ylabel('Depth (cm)')
                    title('Total TOC (wt%)')
                end
            end
            
        end
        
        function plot_TOC(res, ~, swi, str_date)
            figure
            
            set(0,'defaultLineLineWidth', 2)
            set(0,'DefaultAxesFontSize',12)
            
            bsd = res.bsd;
            zgrid = 0:0.1:bsd.zinf;
            
            %%% TOC
            for i=1:length(zgrid)
                [C(i), C1(i,:)] = res.zTOC_RCM.calcC( zgrid(i), bsd, res.swi, res);
                [Cflx(i), C1flx(i,:)] = res.zTOC_RCM.calcCflx( zgrid(i), bsd, res.swi, res);
            end
            subplot(121)
            color = parula(swi.nG);
            for G = 1:swi.nG
                plot(100*C1(:,G)*12/bsd.rho_sed, -zgrid,'Color',color(G,:))
                hold on
            end
            % Plot sum (TOC)
            subplot(122)
            plot(100*C*12/bsd.rho_sed, -zgrid, ':k')
            hold on
            t=xlim;         % to draw penetration depths the correct lengths
            plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
            plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
            plot([0,t(1,2)], [-res.zno3,-res.zno3], 'g--')
            plot([0,t(1,2)], [-res.zso4,-res.zso4], 'r--')
            
            hold off
            xlabel ('TOC (wt%)')
            ylabel('Depth (cm)')
            %            title('Total TOC (wt%)')
        end
        
        function plot_TOC_O2_column(res, debug, swi, str_date)
            % plot single sediment column vs depth
            
            set(0,'defaultLineLineWidth', 2)
            set(0,'DefaultAxesFontSize',12)
            
            bsd = res.bsd;
            zgrid = 0:0.1:bsd.zinf;
            
            % CONCENTRATIONS WITHOUT PO4
            set(0,'defaultLineLineWidth', 2)
            set(0,'DefaultAxesFontSize',12)
            
            % Nitrogen included?
            if(swi.Nitrogen)
                figure;
                
                %%% TOC
                subplot(1,2,1)
                for i=1:length(zgrid)
                    [C(i), C1(i,:)] = res.zTOC_RCM.calcC( zgrid(i), bsd, res.swi, res);
                    [Cflx(i), C1flx(i,:)] = res.zTOC_RCM.calcCflx( zgrid(i), bsd, res.swi, res);
                end
                color = parula(swi.nG);
                for G = 1:swi.nG
                    plot(100*C1(:,G)*12/bsd.rho_sed, -zgrid,'Color',color(G,:))
                    hold on
                end
                % Plot sum (TOC)
                plot(100*C*12/bsd.rho_sed, -zgrid, ':k')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                
                hold off
                xlabel ('TOC (wt%)')
                ylabel('Depth (cm)')
                
                
                text( 3/5*(100*C(1)*12/bsd.rho_sed) ,-60,{['a:' num2str(swi.p_a)],...
                    ['SFD:' num2str(bsd.wdepth)]})
                
                %%% O2
                if(res.zox>0.0)
                    for i=1:length(zgrid)
                        [O2(i), flxO2(i), flxO2D(i), flxO2adv(i)] = res.zO2.calcO2(zgrid(i), bsd, res.swi, res);
                    end
                else
                    O2(i) = 0.0;
                end
                subplot(1,2,2)
                plot(O2, -zgrid, 'b')
                hold on
                t=xlim;         % to draw penetration depths the correct lengths
                plot([0,t(1,2)], [-bsd.zbio,-bsd.zbio], 'k--')
                plot([0,t(1,2)], [-res.zox,-res.zox], 'b--')
                %                 ylim([-20 0.0])
                xlabel ('O_2 (mol/cm^3)')
                ylabel('Depth (cm)')
                %            title ('O2 (mol/cm^3)')
                
            end
        end
        
        
        
        function [k, C0i, Fnonbioi] = RCM(bsd, swi)
            % Implemented by Philip Pika
            % Described in Pika et al. (2020) GMD
            
            % For comparison with original 2G results
            if swi.nG == 2
                C0i(1:2) = 0.1 * 1e-2/12*bsd.rho_sed;       % TOC@SWI (wt%) -> (mol/cm^3 bulk phase), 2.5 sed.density (g/cm3) 0.1
                Fnonbioi = swi.C0*(1-bsd.por)*bsd.w;        % [mol/(cm2 yr)] according non-bioturbated flux
                k = [0.01 0.0001];
                swi.p_a = NaN;
                swi.p_nu = NaN;
            else
                emin = -15;
                emax = -log10(swi.p_a)+2;       % upper k limit for k-bins of multi-G approximation
                if emin >= emax;error('emin >= emax, this cannot be!');end
%                 if emax >= log10(200);emax=log10(200);end
                
                k(1,1)= 10^(emin);
                kk(1,1)=10^(emin);
                F(1,1) = gammainc(swi.p_a*10^emin,swi.p_nu,'lower');
                kk(swi.nG,1)=10^(emax);
                k(swi.nG,1)=10^(emax);
                F(swi.nG,1) = gammainc(swi.p_a*10^emax,swi.p_nu,'upper');
                
                % Define the b.c. for all the intermediate fractions
                
                G=2:swi.nG-1;
                ne=emin+(1:swi.nG-2).*(emax-emin)./(swi.nG-1);
                kk(2:swi.nG-1,1)=10.^ne;
                G_inc_0 = gammainc(swi.p_a*kk(1:swi.nG-2),swi.p_nu,'upper'); % G-1 = 1:end-2
                G_inc_1 = gammainc(swi.p_a*kk(2:swi.nG-1),swi.p_nu,'upper'); % G = 2:end-1
                F(2:swi.nG-1,1) = (G_inc_0 - G_inc_1);
                k(G,1)=kk(1:swi.nG-2)+(kk(2:swi.nG-1)-kk(1:swi.nG-2))/2;
%                 F(F<=eps)=eps;
                if abs(sum(F)-1) > 0.0001;warning('F~=1!!');end
                Fnonbioi = F.* ( swi.C0*(1-bsd.por)*bsd.w ); % NonBioturbated SWI
                C0i = F.*swi.C0;
            end
        end
        
         function res = OMEN_with_DOU_input(BC, anu_pairs)
            % Implemented by Philip Pika
            % Described in Pika et al. (2020) GMD
            
            swi.TwoG_OM_model = 0;

             % function Input

             % BC is a nx1 matric with boundary conditions in the following order:
             % BCin(1):	SFD
             % BCin(2):	dissO2
             % BCin(3):	NO3
             % BCin(4):	TOC
             % BCin(5):	Temp
             % BCin(6):	PO4
             % BCin(8):	SR
             % BCin(7):	nG

             % anu_pairs is a nx2 matrix with parameter a and nu
             
             
            if nargin == 0
                swi = benthic_test.default_swi();
                res.bsd = benthic_main(1);
                res.bsd.usescalarcode = true;
                swi.Nitrogen=true;                                  % calculate N (true/false)
                swi.plot_PO4_DIC_ALK=false;
                AllSpecies = true;
            else
                % NOTE DOM USES FLUX INSTEAD OF CONC, WHY?
                
                % Condition on deep sea sites
                % set wdepth - affects SR and Dbio !!!
                if BC.SFD<6000
                    res.bsd.wdepth = BC.SFD;
                else
                    res.bsd.wdepth = 6000;
                end
                res.bsd = benthic_main(1, res.bsd.wdepth);
                res.bsd.usescalarcode = true;
                
                if ~isnan(BC.SR) == 1
                    res.bsd.w = BC.SR;
                end
                
                % Condition for deep sea site
                % Affects zbio -  sets zbio = 0
                if res.bsd.wdepth > 5200
                    res.bsd.zbio = 0.1;
                end
                
                % Porosity
                if res.bsd.wdepth < 200
                    res.bsd.por = 0.45;% * exp(-0.5e-3*res.bsd.wdepth);
                elseif res.bsd.wdepth > 200 && ...
                        res.bsd.wdepth < 3500
                    res.bsd.por = 0.75;% * exp(-1.7e-4*res.bsd.wdepth);
                elseif res.bsd.wdepth > 3500
                    res.bsd.por = 0.7;% * exp(-0.85e-3*res.bsd.wdepth);
                end
    
                
                %bottom water concentrations
                swi.T = BC.Temp;                        %temperature (degree C)
                swi.C0 = BC.TOC * 1e-2/12*res.bsd.rho_sed;      % TOC concentration at SWI (wt%) -> (mol/cm^3 bulk phase)
                % bottom water concentrations: GENIE mol/kg -> SEDIMENT MODEL needs mol/cm^3
                swi.O20 = BC.dissO2*1E-009;                       % O2  concentration at SWI (mol/cm^3)
                swi.Nitrogen=true;                                  % calculate N (true/false)
                swi.NH40=10.0e-9;                                 	% NH4 concentration at SWI (mol/cm^3)
                swi.SO40=2.8E-005;                                	% SO4 concentration at SWI (mol/cm^3)
                swi.H2S0=0;                                         %H2S concentration at SWI (mol/cm^3)
                swi.PO40 = BC.PO4*1E-009;                           % PO4 concentration at SWI (mol/cm^3)
                swi.NO30 = BC.NO3*1E-009;                           % NO3 concentration at SWI (mol/cm^3)
                swi.Mflux0=365*0.2e-10; %*1/(1-bsd.por)*1/bsd.w;    % actually CONCENTRATION of M at the sediment [mol/cm3] : from flux input  365*0.2e-10 (mol/(cm2*yr))
                swi.DIC0=2.4E-006;                                 	% DIC concentration at SWI (mol/cm^3)
                swi.ALK0=2.4E-006;                                 	% ALK concentration at SWI (mol/cm^3)
                swi.S0=35;                                         	% Salinity at SWI (not used at the moment)
                AllSpecies = true;
                
                swi.plot_PO4_DIC_ALK=true;
                
                
                
                %%%%%%%%%%     Choose k parameterisation    %%%%%%%%%%
                swi.nG = BC.nG;
                swi.p_nu = anu_pairs(2);
                swi.p_a = 10.^anu_pairs(1);
                if anu_pairs>6;warning('Parameter a given as log10? or yrs?');end
                %disp([num2str(res.swi.p_nu) ' ' num2str(res.swi.p_a) ' ' num2str(res.bsd.w)])
                
            end
            % Set default values
            res.zTOC_RCM = benthic_zTOC_RCM(res.bsd);
            
            [res.zTOC_RCM.k, swi.C0i, swi.Fnonbioi] = benthic_test.RCM(res.bsd, swi);
            
            % MIN oxic from Arndt et al. 2013
            %              res.zTOC_RCM.k1=1.0e-4;
            %              res.zTOC_RCM.k2=1.0e-6;
            
            %       after Boudreau 1997 - k dependent on OM flux (in micromol/(cm^2yr):
            %        res.zTOC_RCM.k1 = 2.2*1e-5*(bc(1)*10^6)^2.1;
            % if anoxic, decrease zbio and use anoxic degradation rate
            %                 if(swi.O20 < 5.0e-9 )
            %                     res.bsd.zbio=0.01;
            %                     res.zTOC_RCM.k2 = 0.00001; % modern: 0.001; OAE2: 0.00001
            %                 end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%        RUN OMEN       %%%%%%%%%%%%%%%%%
            res.swi = swi;
            % Initialise
            res.zO2 = benthic_zO2(res.bsd, res.swi);
            res.zxf = 0.0;                              % roll off oxidation at low zox
            if(AllSpecies)
                res.zNO3 = benthic_zNO3(res.bsd, res.swi);
                res.zNH4 = benthic_zNH4(res.bsd, res.swi);
            end
            res.zSO4 = benthic_zSO4(res.bsd, res.swi);
            res.zH2S = benthic_zH2S(res.bsd, res.swi);
            res.zH2S = benthic_zH2S(res.bsd, res.swi);
            res.zPO4_M = benthic_zPO4_M(res.bsd, res.swi);
            res.zDIC = benthic_zDIC(res.bsd, res.swi);
            res.zALK = benthic_zALK(res.bsd, res.swi);
            
            % change PO4 related parameters for margins
            if(res.bsd.wdepth <= 2000)
                tesss=1;
                res.zPO4_M.ksPO4=36.5;         	% Rate constant for kinetic P sorption (1/yr) (Palastanga: 3.65;)
                res.zPO4_M.PO4s=2.0e-9; %10.0e-10;              % Equilibrium concentration for P sorption (mol/cm3)       was 1.5e-9; ; Slomp ea 1996
                res.zPO4_M.Minf=5.2e-15; %1.99e-10; %2.0e-9; %1.0e-10;       % asymptotic concentration for Fe-bound P (mol/cm3)  (was 5.2e-9;)
            end
            
            
            % Calculate OMEN profiles and fluxes
            res = res.zTOC_RCM.calc(res.bsd,res.swi, res);
            % To check the Integration constants
            %             plot_integration_constants()
            if(swi.O20<= 1.0e-18)
                res.zox = 0.0;
                res.zno3=res.zox;
                res.flxswiO2=0.0;
            else
                res = res.zO2.calc(res.bsd, res.swi, res);
            end
            if (AllSpecies)
                if(swi.Nitrogen)
                    res = res.zNO3.calc(res.bsd, res.swi, res);
                else
                    res.zno3=res.zox;
                end
                
                res = res.zSO4.calc(res.bsd, res.swi, res);
                
                if(swi.Nitrogen)
                    res = res.zNH4.calc(res.bsd, res.swi, res);
                end
                res = res.zH2S.calc(res.bsd, res.swi, res);
                res = res.zPO4_M.calc(res.bsd, res.swi, res);
                res = res.zDIC.calc(res.bsd, res.swi, res);
                res = res.zALK.calc(res.bsd, res.swi, res);
            end
            
            
            
            
            
            
            
            
            %%%%% WRITE OUTPUT:
            sed_depth=100.0;
            
            [Cinf, C1inf] = res.zTOC_RCM.calcC( sed_depth, res.bsd, res.swi, res);
            [Cswi, ~] = res.zTOC_RCM.calcC( 0, res.bsd, res.swi, res);
            
            
            %%%% TOC wt %%%%
            res.C1_zinf_wtpc=100*C1inf*12/res.bsd.rho_sed;
            
            res.C_zinf_wtpc=100*Cinf*12/res.bsd.rho_sed;
            
            %             fprintf('both concentration at zinf %g \n',  Cinf);
            %             fprintf('both concentration at swi %g \n',  Cswi);
            %             fprintf('sed preservation of POC %g \n',  Cinf/Cswi);
            
            x = 5;
            % calculate depth integrated OM degradation rates [mol cm-2 yr-1]
            res.Cox_rate_total_xcm = res.zTOC_RCM.calcReac(0.0, x, 1, res.bsd, res.swi, res);
            res.Cox_rate_total =     res.zTOC_RCM.calcReac(0.0, res.bsd.zinf, 1, res.bsd, res.swi, res);
            res.Cox_rate_aerobic =   res.zTOC_RCM.calcReac(0.0, res.zox, 1, res.bsd, res.swi, res);
            res.Cox_perc_aerobic=    res.Cox_rate_aerobic/res.Cox_rate_total*100;
            if (AllSpecies)
                if(swi.Nitrogen)
                    res.Cox_rate_denitr =res.zTOC_RCM.calcReac(res.zox, res.zno3, 1, res.bsd, res.swi, res);
                end
                res.Cox_rate_sulfred =   res.zTOC_RCM.calcReac(res.zno3, res.bsd.zinf, 1, res.bsd, res.swi, res);
                res.Cox_perc_sulfred=    res.Cox_rate_sulfred/res.Cox_rate_total*100;
            end
            
            % calculate mean OM concentration in upper x cm
            res.Mean_OM = 1/x * 100*12/res.bsd.rho_sed*res.zTOC_RCM.calcOM(0.0, x, 1, res.bsd, res.swi, res);
            
            
            %%%% Oxygen %%%%
            if(res.zox>=x)
                res.Cox_perc_aerobic_xcm = 100;
            else
                res.Cox_perc_aerobic_xcm = res.Cox_rate_aerobic/res.Cox_rate_total_xcm *100;
            end
            
%             %             check O2 demand using O2 to C ratio and (convert POC concentr. to flux analog to fortran)
%             %             POC_flux*OC = POC_conc * w * 1/(1 - por) * OC
%             %             O2_demand_flux = -(sum(res.swi.Fnonbioi))*res.bsd.OC/((1-res.bsd.por)./res.bsd.por)
%             %             O2_demand_1 = sum(res.swi.C0)*res.bsd.OC
%             %             O2_demand_2 = sum(res.swi.C0)*res.bsd.w*res.bsd.OC
%             
%             %             if res.zox < res.bsd.zinf   % <= so handle case of fully oxic with zox = zinf
%             % basis functions at z
            
             if(swi.O20<= 1.0e-18)
                res.DOU_profile = 0;
                res.DOU_profile_alt = 0;
                res.flxO2D_PP = 0
            else
            % Pure diffusive Oxygen flux form profile
            x(1)=0;x(2)=0.05; x(3)=0.1;
            % Removed The temperature dependence becasue more in tune with
            % Glud 2008.
            D = (res.zO2.qdispO2);%+res.zO2.adispO2*res.swi.T);
            [ e, ~, f, ~, g, ~] = res.zTOC_RCM.calcfg_l12(x(1), res.bsd, res.swi, res, res.zO2.reac1, 0, res.rO2.ls);
            O2(1) = res.rO2.AO2.*e + res.rO2.BO2.*f + g;
            [ e, ~, f, ~, g, ~] = res.zTOC_RCM.calcfg_l12(x(2), res.bsd, res.swi, res, res.zO2.reac1, 0, res.rO2.ls);
            O2(2) = res.rO2.AO2.*e + res.rO2.BO2.*f + g;
            [ e, ~, f, ~, g, ~] = res.zTOC_RCM.calcfg_l12(x(3), res.bsd, res.swi, res, res.zO2.reac1, 0, res.rO2.ls);
            O2(3) = res.rO2.AO2.*e + res.rO2.BO2.*f + g;
            dx1 = x(2)-x(1);	% dx1 = Depth(2)-Depth(1);
            dx2 = x(3)-x(2);  % dx2 = Depth(3)-Depth(2);
            
            % MolDiffusion, mod. Broudreau, taken from Fluxes_SWI_bioirr_Philip
            % OMEN-SED defines positive flux out of Sed, hence (-) removed
            res.DOU_profile = D *...
                ( O2(3) - O2(2)*(1+dx2^2/dx1^2+2*dx2/dx1) + O2(1)* (dx2^2/dx1^2+2*dx2/dx1))/ ...
                (-dx2-dx2^2/dx1);
            
            
            % DOU calculation
            % MolDiffusion, mod. Broudreau, taken from Fluxes_SWI_bioirr_Philip
            % OMEN-SED defines positive flux out of Sed, hence (-) removed,
            % however if O2 gradients are too large, there is a problem
            % with the equation and needs to chnage to a 2-point Eq.
            
            % This is not the 'proper way' to calculate DOU, mainly because DOU is
            % calculated with a simple gradient. Also Matteo mentioed that if the
            % Flux is calculated with the 3 point Eq. it fails. This leads me to
            % avoid it and use the simple 2 point gradient.

            res.DOU_profile_alt = D*(O2(2) - O2(1)) / dx1; % mol/cm2/yr
             
            
            
            % This next section is taken from the zO2 function, but has
            % been modified such that the diffusion coefficent is only
            % defined by its diffisuve component and no Db nor xirr
            
            % Calculate O2 conc and flux at depth z from solution
            z=0;
            if z <= res.zox    % <= so handle case of fully oxic with zox = zinf
                % basis functions at z
                [ e, dedz, f, dfdz, g, dgdz] ...
                    = res.zTOC_RCM.calcfg_l12(z, res.bsd, res.swi, res, res.zO2.reac1, 0, res.rO2.ls);
                if z < res.bsd.zbio  % < so handle zbio = 0
                    D = ( res.zO2.qdispO2+ res.zO2.adispO2*res.swi.T); % no Db, no Birr
                else
                    D = ( res.zO2.qdispO2+ res.zO2.adispO2*res.swi.T); % no Db, no Birr
                end
                res.O2_PP = res.rO2.AO2.*e + res.rO2.BO2.*f + g;
               % res.flxO2D_PP = res.bsd.por.*D.*(res.rO2.AO2.*dedz+res.rO2.BO2.*dfdz + dgdz); % diffusive component
                res.flxO2D_PP = D.*(res.rO2.AO2.*dedz+res.rO2.BO2.*dfdz + dgdz); % diffusive component no por
                res.flxO2adv_PP = - res.bsd.por.*res.bsd.w*res.O2_PP;      % advective component
                res.flxO2_PP = res.flxO2D_PP + res.flxO2adv_PP;            % total
            else
                res.O2_PP = 0;
                res.flxO2_PP = 0;
                res.flxO2D_PP = 0;
                res.flxO2adv_PP = 0;
            end
            
            if(res.swi.O20<=0.0)
                res.O2 = 0.0;
                res.flxO2 = 0.0;
                res.flxO2D = 0.0;
                res.flxO2adv = 0.0;
            else
                [res.O2, res.flxO2, res.flxO2D, res.flxO2adv] = res.zO2.calcO2(0, res.bsd, res.swi, res);
            end
             end % end anoxic check
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%  MEAN PO4 concentration in bioturbated layer (10cm)  %%%%%%%%%%%%%%%%%%%%
            calc_PO4=false;
            if(calc_PO4)
                zgrid = 0:0.5:10;
                for i=1:length(zgrid)
                    [PO4(i), flxPO4(i), M(i), flxM(i), e_M(i), f_M(i), p_M(i), q_M(i), g_M(i), dedz_M(i), dfdz_M(i), dpdz_M(i), dqdz_M(i), dgdz_M(i)] = ...
                        res.zPO4_M.calcPO4_M(zgrid(i), res.bsd, res.swi, res);
                end
                res.Mean_PO4 = sum(PO4)/length(zgrid);
                res.Mean_M = sum(M)/length(zgrid);
            end
            
            % Handling other cases
            if AllSpecies == 0
                res.zno3 = 1;
                res.flxswiNO3  = 1;
                res.flxswiNH4 = 1;
                res.flxswiSO4 = 1;
                res.flxswi_P = 1;
            end
            
% %             benthic_test.plot_TOC_O2_column(res, false, swi, 'test')
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%  TEST PROFILES  %%%%%%%%%%%%%%%%%%%%
            %
            %             %                   if(bsd.wdepth < 500)
            %             if(res.flxswi_P > 0.0)
            %                 res.bsd.wdepth
            %                 benthic_test.plot_column(res, false, res.swi, '_SWI_P')
            %             end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%  PLOT PROFILES  %%%%%%%%%%%%%%%%%%%%
            %             str_date = [num2str(res.swi.nG) 'G_a=' num2str(res.swi.p_a) '_nu=' num2str(res.swi.p_nu) '_O20_' num2str(res.swi.O20)];
            %             benthic_test.plot_column(res, false, swi, str_date)
            %             benthic_test.plot_TOC(res, false, swi, str_date)
            
            %             if nargin < 3
            %                 Results(1,:) = [res.swi.p_a res.swi.p_nu res.flxswiO2 res.zox O2 flxO2 flxO2D flxO2adv res.zno3 res.flxswiNO3 res.flxswiNH4 res.flxswiSO4 res.flxswi_P];
            %                 benthic_test.plot_column(res, false, res.swi, ['Exp_',num2str(ExpNr) '-a=' num2str(swi.p_a) ])
            %                 benthic_test.plot_TOC_O2_column(res, false, res.swi, ['Exp_',num2str(ExpNr) '-a=' num2str(swi.p_a) ])
            %             end
            %                             print('-dpsc2', ['0_PROFILES_' str_date '.eps']);
        end
        
       
        
    end
    
end