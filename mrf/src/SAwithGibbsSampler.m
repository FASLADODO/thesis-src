%%
function [labels_GlbMin] = SAwithGibbsSampler(linelist, iLabels, nstep, nlevel, iTemp, mrf, Cliques, save_logs)

    if(~exist('save_logs'))
        save_logs = 0;
    end

    mrf.CliqPotMin = -1 * (-mrf.params.Kl*2 + mrf.params.Kc*sind(180));
    
    for i=1:size(linelist,2)
        
        linelist(i).SegPot(1) = (-0.4587 + linelist(i).prob);
        
        if(mrf.params.allowjunc == 0)
            linelist(i).SegPot(2) = 0;
        else
            linelist(i).SegPot(2) = (0.5413 - linelist(i).prob);
        end
        
    end
   
    
    E_new = Inf;
    E_prv = Inf;
    E_GlbMin = Inf;
    deltaE = Inf;

    T = iTemp;
    c = 0.5;
    K = 1;
    
    [Grp] = CreateGroupMatrix(linelist);
    
    nconn = size(linelist, 2);    % # of connections
    
    labels        = iLabels;
    labels_GlbMin = iLabels; 

    ngrp = size(Grp{1},1);

    labels_allp = zeros(ngrp, 2^ngrp);
    for m=1:(2^ngrp)
        labels_allp(:,m)=de2bi((m-1),ngrp)';
    end
   
    if(save_logs)
        datetime = datestr(now, '(yyyy.mm.dd)_(HH.MM.SS)');
    end
    
    while(deltaE >= 0.000 && K <= nlevel)
        
        if(save_logs)
            LogFile = fopen(sprintf('MRF/mrf_optimization_%d_%s.log', K, datetime),'w+');
        end
        
        for k=1:nstep
            
            %[Z] = CalculatePartitionFunction(Cliques, mrf, linelist);
            
            for i=1:size(Grp,1)

                labels_l = repmat(labels,1,(2^ngrp));
                labels_l(Grp{i},:) = labels_allp;
                
                for m=1:(2^ngrp)
                    prob(m) = 0;
                    for n=1:ngrp
                        prob(m) = prob(m) + exp(-MRFLocalEnergy(Grp{i}(n) , linelist, labels_l(:,m), Cliques, mrf)/T);
                    end
                end

                prob = prob ./ sum(prob);
                sumE = 0;
                r = rand(1);
                for m=1:(2^ngrp)
                    sumE = sumE + prob(m);
                    if(r < sumE)
                        labels_gibbs = labels_l(:,m);
                        break;
                    end
                end

                % simulated annealing
                E = CalculateEnergyLL(linelist, labels_gibbs, Cliques, mrf);
                if(E < E_prv)
                    % accept change
                    E_new = E;
                    labels = labels_gibbs;
                else
                    dE = (E - E_prv);
                    % Z = exp(-E/T) + exp(-E_old/T);
                    Z = 1;
                    p = (1/Z) * exp(-dE/T);
                    r = rand(1);
                    if(r < p)
                        % accept change
                        E_new = E;
                        labels = labels_gibbs;
                    end

                end

                if(E_new < E_GlbMin)
                    E_GlbMin = E_new;
                    labels_GlbMin = labels;
                end

                deltaE = abs(E_new - E_prv);    % stop when energy change is small    
                E_prv = E_new;
                
                if(save_logs)
                    fwrite(LogFile, sprintf('\t__%4d__%02d(%3d), E_new = %.2f, E_prev = %.2f, E_glb = %.2f\n', i, K, k, E_new, E_prv, E_GlbMin));
                end
            end
            
            fprintf('_%02d(%3d), Energy = %.3f, deltaE = %.3f\n', K, k, E_new, deltaE);
            
            if(save_logs)
                fwrite(LogFile, sprintf('__%02d(%3d), E_new = %.2f, E_prev = %.2f, E_glb = %.2f\n', K, k, E_new, E_prv, E_GlbMin));   
            end
        end
        
        labels = labels_GlbMin;
        
        T = T * c;      % Decrease temperature
        K = K + 1;      % Advance iteration counter

        if(save_logs)
            fclose(LogFile);
        end
    end            
end

%%
function [Grp] = CreateGroupMatrix(linelist)

    nconn = size(linelist, 2);

    tmp = [linelist.c];

    Cent(:,1) = tmp(1:2:end);
    Cent(:,2) = tmp(2:2:end);

    Grp = cell(nconn,1);
    
    for i=1:nconn
       D = [(1:size(Cent,1))' sqrt((Cent(:,1)-linelist(i).c(1)).^2 + (Cent(:,2)-linelist(i).c(2)).^2)];
       D = sortrows(D,2);
       nodes = D(:,1);
       Grp{i} = nodes(1:5);
    end
    
end
%%



