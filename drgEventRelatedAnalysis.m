function [log_P_t,no_trials_w_event,which_event,f,out_times,times,ERLFP_per_trial,phase_per_trial]=drgEventRelatedAnalysis(handles)
%Performs an event-related analysis. The event is signaled by a sharp chane
%in the reference voltage. This is used to analyze lick-related changes in
%LFP

which_event=[];
anglereference = [];
angleLFP = [];
delta_phase_timecourse=[];

%Generates a trial per trial phase histogram
sessionNo=handles.sessionNo;
Fs=floor(handles.drg.session(sessionNo).draq_p.ActualRate);
lowF1=handles.peakLowF;
lowF2=handles.peakHighF;
highF1=handles.burstLowF;
highF2=handles.burstHighF;
pad_time=handles.time_pad;
n_phase_bins=handles.n_phase_bins;

window=round(handles.window*handles.drg.draq_p.ActualRate); 
noverlap=round(handles.noverlap*handles.drg.draq_p.ActualRate); 

no_time_pts=floor(handles.window*handles.drg.session(sessionNo).draq_p.ActualRate)+1;
    times=[1:no_time_pts]/handles.drg.session(sessionNo).draq_p.ActualRate;
    times=times-(handles.window/2);

freq=4:1:95;

%Enter trials
firstTr=handles.trialNo;
lastTr=handles.lastTrialNo;

%Calculate the threshold value to detect a lick
all_refs=[];
for trNo=firstTr:lastTr
    
    if handles.displayData==1
        trial_no=trNo
    end
    
    evNo = drgFindEvNo(handles,trNo,sessionNo);
    if evNo~=-1
        excludeTrial=drgExcludeTrialLFP(handles.drg,handles.peakLFPNo,handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo),sessionNo);
        
        if excludeTrial==0
            %Note: handles.peakLFPNo is the reference LFP
            [reference, trialNo, can_read1] = drgGetTrialLFPData(handles, handles.peakLFPNo, evNo, handles.evTypeNo, handles.time_start, handles.time_end);
            [LFP, trialNo, can_read2] = drgGetTrialLFPData(handles, handles.burstLFPNo, evNo, handles.evTypeNo, handles.time_start, handles.time_end);

            if (can_read1==1)&(can_read2==1)
                all_refs=[all_refs reference];
            end
        end
    end
end

thershold_ref=prctile(all_refs,1)+((prctile(all_refs,99)-prctile(all_refs,1))/2);

%First find the time range for the spectrogram
if handles.subtractRef==1
    if handles.time_start+handles.time_pad<handles.startRef+handles.time_pad
        min_t=handles.time_start+handles.time_pad-(handles.window/2);
    else
        min_t=handles.startRef+handles.time_pad-(handles.window/2);
    end
    
    if handles.time_end-handles.time_pad>handles.endRef-handles.time_pad
        max_t=handles.time_end-handles.time_pad+handles.window;
    else
        max_t=handles.endRef-handles.time_pad+handles.window;
    end
else
    min_t=handles.time_start+handles.time_pad-(handles.window/2);
    max_t=handles.time_end-handles.time_pad+handles.window;
end


%Now get the LFP phase of the events

events=[];
phase=[];
time=[];
no_events=0;
no_trials=0;
no_trials_w_event=0;

ERLFP=[];
all_Power_per_event=[];
ref_power_per_event=[];
phase_per_trial=[];
ERLF_per_trial=[];

log_P_t=[];
 
for trNo=firstTr:lastTr
    
    if handles.displayData==1
        trial_no=trNo
    end
    
    evNo = drgFindEvNo(handles,trNo,sessionNo);
    if evNo~=-1
        excludeTrial=drgExcludeTrialLFP(handles.drg,handles.peakLFPNo,handles.drg.session(sessionNo).events(handles.evTypeNo).times(evNo),sessionNo);
        
        if excludeTrial==0
             
            %Note: handles.peakLFPNo is the reference LFP
            [reference, trialNo, can_read1] = drgGetTrialLFPData(handles, handles.peakLFPNo, evNo, handles.evTypeNo, min_t, max_t);
            [LFP, trialNo, can_read2] = drgGetTrialLFPData(handles, handles.burstLFPNo, evNo, handles.evTypeNo, min_t, max_t);
            
            if (can_read1==1)&(can_read2==1)
                no_trials=no_trials+1;
                time(no_trials)=handles.drg.session(sessionNo).trial_start(trialNo);
                which_trial(no_trials)=1;
                perCorr_per_histo(no_trials)=50;
                
                
                %Get LFP phase
                bpFiltLFP = designfilt('bandpassiir','FilterOrder',20, ...
                    'HalfPowerFrequency1',highF1,'HalfPowerFrequency2',highF2, ...
                    'SampleRate',Fs);
                thfiltLFP=filtfilt(bpFiltLFP,LFP);
                thisangleLFP = angle(hilbert(thfiltLFP)); % LFP phase
                angleLFP = [angleLFP thisangleLFP];
                
                %Get the spectrogram
                [S,f,t,P]=spectrogram(detrend(double(LFP)),window,noverlap,freq,handles.drg.session(handles.sessionNo).draq_p.ActualRate);
                
                times_spec=t+min_t;
                
                
                %Get events
                
                %Trim off the time pads
                ii_start=floor(((handles.time_start-handles.startRef)+(handles.window/2))*handles.drg.session(sessionNo).draq_p.ActualRate);
                delta_ii_end=floor((handles.window)*handles.drg.session(sessionNo).draq_p.ActualRate);
                ref=reference(ii_start:end-delta_ii_end-1);
                thaLFP=thisangleLFP(ii_start:end-delta_ii_end-1);
                
                if ref(1)>thershold_ref
                    ii=find(ref<thershold_ref,1,'first');
                else
                    ii=1;
                end
                
                the_end=0;
                
                phase_this_trial=[];
                all_Power_these_events=[];
                ref_power_these_events=[];
                ERLFP_this_trial=[];
                no_evs_this_trial=0;
                while the_end==0
                    next_event=find(ref(ii:end)>thershold_ref,1,'first');
                    if isempty(next_event)
                        the_end=1;
                    else
                        no_events=no_events+1;
                        ii=ii+next_event-1;
                        events(no_events)=ii;
                        time(no_events)=handles.time_start+pad_time+(ii/handles.drg.session(sessionNo).draq_p.ActualRate);
                        phase(no_events)=thaLFP(ii);
                        no_evs_this_trial=no_evs_this_trial+1;
                        phase_this_trial(no_evs_this_trial)=thaLFP(ii);
                        
                        ERLFP(no_events,:)=LFP(1,floor(ii_start+ii-(handles.window/2)*handles.drg.session(sessionNo).draq_p.ActualRate):...
                            floor(ii_start+ii+(handles.window/2)*handles.drg.session(sessionNo).draq_p.ActualRate));
                        
                        ERLFP_this_trial(no_evs_this_trial,:)=LFP(1,floor(ii_start+ii-(handles.window/2)*handles.drg.session(sessionNo).draq_p.ActualRate):...
                            floor(ii_start+ii+(handles.window/2)*handles.drg.session(sessionNo).draq_p.ActualRate));
                        
                        [mint,mint_ii]=min(abs(times_spec-time(no_events)));
                        out_times=times_spec((times_spec>=times_spec(mint_ii)-handles.window/2)&(times_spec<=times_spec(mint_ii)+handles.window/2));
                        lot=length(out_times);
                        
                        all_Power_per_event(no_events,1:length(f),1:length(out_times))=P(:,(times_spec>=times_spec(mint_ii)-handles.window/2)&(times_spec<=times_spec(mint_ii)+handles.window/2));
                        all_Power_these_events(no_evs_this_trial,1:length(f),1:length(out_times))=P(:,(times_spec>=times_spec(mint_ii)-handles.window/2)&(times_spec<=times_spec(mint_ii)+handles.window/2));
                       
                        if handles.subtractRef==1
                            ref_power_per_event(no_events,:)=mean(P(:,(times_spec>=handles.startRef+handles.time_pad)&(times_spec<=handles.endRef-handles.time_pad)),2)';
                            ref_power_these_events(no_evs_this_trial,:)=mean(P(:,(times_spec>=handles.startRef+handles.time_pad)&(times_spec<=handles.endRef-handles.time_pad)),2)';
                        end
                        
                        end_event=find(ref(ii:end)<thershold_ref,1,'first');
                        if isempty(end_event)
                            the_end=1;
                        else
                            ii=ii+end_event-1;
                        end
                    end
                end
                
                if no_evs_this_trial>0
                    no_trials_w_event=no_trials_w_event+1;
                    phase_per_trial(no_trials_w_event)=circ_mean(phase_this_trial');
                    ERLFP_per_trial(no_trials_w_event,:)=mean(ERLFP_this_trial,1);
                    %Per trial event related spectrogram
                    %Event-related spectrogram
                    %Timecourse doing average after log
                    %Get max and min
                    if handles.subtractRef==0
                        log_P_timecourse=zeros(length(f),length(out_times));
                        log_P_timecourse(:,:)=mean(10*log10(all_Power_per_event),1);
                        log_P_t(no_trials_w_event,1:length(f),1:length(out_times))=log_P_timecourse(:,:);
                    else
                        log_P_timecourse=zeros(length(f),length(out_times));
                        log_P_timecourse(:,:)=mean(10*log10(all_Power_per_event),1);
                        log_P_timecourse_ref=zeros(length(f),length(out_times));
                        log_P_timecourse_ref(:,:)=repmat(mean(10*log10(ref_power_per_event),1)',1,length(out_times));
                        log_P_t(no_trials_w_event,1:length(f),1:length(out_times))=log_P_timecourse(:,:)-log_P_timecourse_ref(:,:);
                    end
                    
                    if isfield(handles,'drgbchoices')
                        for evTypeNo=1:length(handles.drgbchoices.evTypeNos)
                            switch handles.evTypeNo
                                case 1
                                    %tstart is the reference event
                                    if handles.drgbchoices.evTypeNos(evTypeNo)==1
                                        %This is tstart
                                        if sum(handles.drg.session(1).events(handles.drgbchoices.evTypeNos(evTypeNo)).times==handles.drg.session(1).events(handles.drgbchoices.referenceEvent).times(evNo))>0
                                            which_event(evTypeNo,no_trials_w_event)=1;
                                        else
                                            which_event(evTypeNo,no_trials_w_event)=0;
                                        end
                                    else
                                        %These are not tstart, and the time
                                        %should be compared at OdorOn
                                        %This is tstart
                                        if sum(handles.drg.session(1).events(handles.drgbchoices.evTypeNos(evTypeNo)).times==handles.drg.session(1).events(2).times(evNo))>0
                                            which_event(evTypeNo,no_trials_w_event)=1;
                                        else
                                            which_event(evTypeNo,no_trials_w_event)=0;
                                        end
                                    end
                                otherwise
                                    %OdorOn is the reference event
                                    if sum(handles.drg.session(1).events(handles.drgbchoices.evTypeNos(evTypeNo)).times==handles.drg.session(1).events(handles.drgbchoices.referenceEvent).times(evNo))>0
                                        which_event(evTypeNo,no_trials_w_event)=1;
                                    else
                                        which_event(evTypeNo,no_trials_w_event)=0;
                                    end
                            end
                            
                            
                            
                        end
                    end
                end
                
                
                
                
            end
        end
    end
    
    %end %if eventstamps...
end %for evNo

if handles.displayData==1
    

    %Scatter plot of phase as a function of time
    try
        close 3
    catch
    end
    
    hFig3 = figure(3);
    set(hFig3, 'units','normalized','position',[.05 .1 .65 .3])
    
    hold on
    for ii=1:no_events
       plot(time(ii), pi*phase(ii)/180,'ob')
    end
    xlim([handles.time_start+pad_time handles.time_end-pad_time]);
    ylim([0 360])
    xlabel('Time (s)')
    ylabel('Phase degrees')
    title('Timecourse for the event-related phase')
        
    %Avearge event-related filtered LFP
    try
        close 4
    catch
    end
    
    hFig4 = figure(4);
    set(hFig4, 'units','normalized','position',[.05 .5 .3 .3])
    
    no_time_pts=floor(handles.window*handles.drg.session(sessionNo).draq_p.ActualRate)+1;
    times=[1:no_time_pts]/handles.drg.session(sessionNo).draq_p.ActualRate;
    times=times-(handles.window/2);
    
    shadedErrorBar(times,mean(ERLFP,1)-mean(mean(ERLFP,1)),std(ERLFP,0,1)/sqrt(no_events),'-b')
    
    title('Event-related LFP')
    xlim([-0.5 0.5])
    ylim([-250 250])
    ylabel('uV')
    xlabel('Time (s)')
    
    
    %Event-related spectrogram
    %Timecourse doing average after log
    %Get max and min
    if handles.subtractRef==0
        log_P_timecourse=zeros(length(f),length(out_times));
        log_P_timecourse(:,:)=mean(10*log10(all_Power_per_event),1);
        if handles.autoscale==1
            maxLogP=prctile(log_P_timecourse(:),99);
            minLogP=prctile(log_P_timecourse(:),1);
        else
            maxLogP=handles.maxLogP;
            minLogP=handles.minLogP;
        end
    else
        log_P_timecourse=zeros(length(f),length(out_times));
        log_P_timecourse(:,:)=mean(10*log10(all_Power_per_event),1);
        log_P_timecourse_ref=zeros(length(f),length(out_times));
        log_P_timecourse_ref(:,:)=repmat(mean(10*log10(ref_power_per_event),1)',1,length(out_times));
        if handles.autoscale==1
            maxLogP=prctile(log_P_timecourse(:)-log_P_timecourse_ref(:),99);
            minLogP=prctile(log_P_timecourse(:)-log_P_timecourse_ref(:),1);
        else
            maxLogP=handles.maxLogP;
            minLogP=handles.minLogP;
        end
    end
    
    %Note: Diego added this on purpose to limit the range to 10 dB
    %This results in emphasizing changes in the top 10 dB
    if maxLogP-minLogP>10
        minLogP=maxLogP-10;
    end
    
    
    try
        close 1
    catch
    end
    
    %Plot the timecourse
    hFig1 = figure(1);
    set(hFig1, 'units','normalized','position',[.07 .1 .55 .3])
    
    
    if handles.subtractRef==0
        drg_pcolor(repmat(out_times-mean(out_times),length(freq),1)',repmat(freq,length(out_times),1),log_P_timecourse')
    else
        drg_pcolor(repmat(out_times-mean(out_times),length(freq),1)',repmat(freq,length(out_times),1),log_P_timecourse'-log_P_timecourse_ref')
    end
    
    colormap jet
    shading interp
    caxis([minLogP maxLogP]);
    xlabel('Time (sec)')
    ylabel('Frequency (Hz)');
    title(['Event-related power spectrogram (dB)' handles.drg.session(1).draq_d.eventlabels{handles.evTypeNo}])
    
    try
        close 2
    catch
    end
    
    hFig2 = figure(2);
    set(hFig2, 'units','normalized','position',[.63 .1 .05 .3])
    
    prain=[minLogP:(maxLogP-minLogP)/99:maxLogP];
    drg_pcolor(repmat([1:10],100,1)',repmat(prain,10,1),repmat(prain,10,1))
    colormap jet
    shading interp
    ax=gca;
    set(ax,'XTickLabel','')    %Rose plot histogram of the phase of the events
    ylabel('dB')
    
    %Phase rose plot
    try
        close 5
    catch
    end

    hFig5 = figure(5);
    set(hFig5, 'units','normalized','position',[.69 .1 .3 .3])
    
    if no_events>0
        rose(pi*phase/180,12)
        title('LFP phase of events')
    end
    
    pffft=1;
end




