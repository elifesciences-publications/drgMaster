function drgPlotCrossCorr(handles)
%Plot autocorrelaogram

noShuffles=5;
sessionNo=handles.drg.unit(handles.unitNo).sessionNo;

%Enter trials
firstTr=handles.trialNo;
lastTr=handles.lastTrialNo;

bin_size=(0.006/0.05)*handles.corr_window;
auto_width=handles.corr_window;
nobins=floor(2*(auto_width/bin_size));
delta_times=[-auto_width+bin_size/2:bin_size:auto_width-bin_size/2];
noTrials=0;
spike_times=[];
spike_times=handles.drg.unit(handles.unitNo).spike_times;
spike_times2=handles.drg.unit(handles.unitNo2).spike_times;
Auto=zeros(1,nobins);
no_comp_spikes=0;
shAuto=zeros(1,nobins);
no_comp_spikes_sh=0;
time_start=handles.time_start+handles.time_pad;
time_end=handles.time_end-handles.time_pad;


for trNo=firstTr:lastTr
    
    if handles.save_drgb==0
        trial_no=trNo
    end
    
    evNo = drgFindEvNo(handles,trNo,sessionNo);
    
    if evNo~=-1
        
        %evNo
        excludeTrial=drgExcludeTrial(handles.drg,handles.drg.unit(handles.unitNo).channel,handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo),sessionNo);
        
        if excludeTrial==0
            
            noTrials=noTrials+1;
            these_spikes=(spike_times>handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo)+time_start+auto_width)&...
                (spike_times<=handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo)+time_end-auto_width);
            these_spike_times=spike_times(these_spikes)-(handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo)+time_start);
            
            these_spikes2=(spike_times2>handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo)+time_start+auto_width)&...
                (spike_times2<=handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo)+time_end-auto_width);
            these_spike_times2=spike_times2(these_spikes2)-(handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo)+time_start);
            
            for spkref=1:length(these_spike_times)
                for spk=1:length(these_spike_times2)
                    
                    deltat=these_spike_times2(spk)-these_spike_times(spkref);
                    if abs(deltat)<auto_width
                        
                        this_bin=fix(deltat/bin_size)+floor(auto_width/bin_size)+1;
                        if (this_bin>0)&(this_bin<=nobins) 
                            Auto(1,this_bin)=Auto(1,this_bin)+1;
                        end
                    end
                    
                end
            end %for spkref
            no_comp_spikes=no_comp_spikes+length(these_spike_times2)-1;
            
            %Now do random shuffled spikes
            for noS=1:noShuffles
                shuf_spike_times=(time_end-time_start-2*+auto_width)*rand(1,length(these_spike_times))+auto_width;
                shuf_spike_times2=(time_end-time_start-2*+auto_width)*rand(1,length(these_spike_times2))+auto_width;
                for spkref=1:length(these_spike_times)
                    for spk=1:length(these_spike_times2)
                        
                        deltat=shuf_spike_times2(spk)-shuf_spike_times(spkref);
                        if abs(deltat)<auto_width
                            
                            this_bin=fix(deltat/bin_size)+floor(auto_width/bin_size);
                            if (this_bin>0)&(this_bin<=nobins)
                                shAuto(1,this_bin)=shAuto(1,this_bin)+1;
                            end
                            
                            
                        end
                        
                    end
                end %for spkref
                no_comp_spikes_sh=no_comp_spikes_sh+length(these_spike_times2)-1;
            end
        end
        %end
        %end %if eventstamps...
    end %if evNo
end %for trNo=

no_trials_included=noTrials

if no_comp_spikes~=0
    Auto=Auto/no_comp_spikes;
end

if no_comp_spikes_sh~=0
    shAuto=shAuto/no_comp_spikes_sh;
end

%Now plot the crosscorrelogram
try
    close 1
catch
end

%Plot the timecourse
hFig1 = figure(1);
set(hFig1, 'units','normalized','position',[.02 .4 .5 .5])

subplot(2,1,1)
bar(delta_times,Auto,'b');
title(['Cross Correlogram for ' handles.drg.session.eventlabels{handles.evTypeNo}])
ylabel('Correlation coefficient')
xlabel('delta time (sec)')

%Now plot the autocorrelogram - random
subplot(2,1,2)
bar(delta_times,Auto-shAuto,'b');
title(['Cross Correlogram -random for ' handles.drg.session.eventlabels{handles.evTypeNo}])
ylabel('Correlation coefficient')
xlabel('delta time (sec)')
y_max=max(Auto-shAuto);
if y_max~=0
    ylim([0 1.2*y_max])
else
    ylim([0 1.2])
end
