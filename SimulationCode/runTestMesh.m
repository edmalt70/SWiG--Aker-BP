%> @brief Example script to run multiple mesh network
%> simulations 
ModulatorList = {
    genericDSSSModulator(true,false)
    genericDSSSModulator(false,false)
    genericDSSSModulator(false,true)
    SWIGPrimitiveModulator(false,true)
    SWIGModulator(false,false)
    QPSKModulator(false,false)
    };
nodeRange = 6000;
numNodes = 15;
rng(0);
locations=nodeRange*rand(numNodes,3);
%make vertical range much smaller
vertRangeRatio = 0.1;
locations(:,3) = locations(:,3)*vertRangeRatio;
vertRange = vertRangeRatio * nodeRange;
numNodes = size(locations,1);
modulatorIndexList = 1:4;
overallStats = cell(length(modulatorIndexList),1);
for modulatorIndex = 1:length(modulatorIndexList)
    thisModulator = modulatorIndexList(modulatorIndex);
    %build a very simple set of routing tables based on distance
    routingTableCollection = cell(numNodes,1);
    for i=1:length(routingTableCollection)
        routingTableCollection{i}=[];
    end
    emptyRoutingTableCollection = routingTableCollection;
    repeaterNumberToTest = [2 4];
    stats=cell(length(repeaterNumberToTest),1);
    for repIndex = 1:length(repeaterNumberToTest)
        numRepeaters = repeaterNumberToTest(repIndex);
        switch numRepeaters
            case 4
                % 4 repeaters
                idealPoints =[
                    [nodeRange*(1/3) nodeRange*(1/3) 0.5*vertRange];...
                    [nodeRange*(1/3) nodeRange*(2/3) 0.5*vertRange];...
                    [nodeRange*(2/3) nodeRange*(1/3) 0.5*vertRange];...
                    [nodeRange*(2/3) nodeRange*(2/3) 0.5*vertRange]
                    ];
                %set minimum route distance
                minRouteDistance = 0.25 * nodeRange;
            case 2
                idealPoints =[
                    [nodeRange*(1/3) nodeRange*(1/3) 0.5*vertRange];...
                    [nodeRange*(2/3) nodeRange*(2/3) 0.5*vertRange];...
                    ];
                %set minimum route distance
                minRouteDistance = 0.15 * nodeRange;
            case 1
                idealPoints=[0.5*nodeRange 0.5*nodeRange 0.5*vertRange];
                minRouteDistance = 0.15 * nodeRange;
            case 0
                idealPoints=[];
            otherwise
                error('Invalid number of repeaters')
        end
        %set up the nodes
        maxQueueDepth = 1024;
        nodes = cell(numNodes,1);
        for i = 1:numNodes
            nodes{i}=nodeClass(locations(i,:),ModulatorList,i,maxQueueDepth); %#ok<*SAGROW>
            nodes{i}.setModulator(thisModulator);  %SWiG primitive
        end
        %set up the mesh routing tables
        if numRepeaters>0
            %go get the nodes closest to the desired repeater points
            repeaterIDs=zeros(size(idealPoints,1),1);
            for i=1:length(repeaterIDs)
                d2 = sum((locations - repmat(idealPoints(i,:),size(locations,1),1)).^2,2);
                [~,which] = min(d2);
                repeaterIDs(i) = which;
            end
            %we now have our infrastructure nodes. Let's build each one's
            %client list
            clientList=cell(numRepeaters,1);
            infrastructureLocations=zeros(numRepeaters,3);
            for i=1:numRepeaters
                clientList{i}=[];
                infrastructureLocations(i,:)=nodes{repeaterIDs(i)}.getLocation;
            end
            %clients are added to nearest infrastructure node
            for i=1:length(nodes)
                loc=repmat(nodes{i}.location,numRepeaters,1);
                d2=sum((loc-infrastructureLocations).^2,2);
                [val,which]=min(d2);
                if val>1  %don't add yourself!
                    clientList{which}=[clientList{which};i];
                end
            end
            %now, we need to build the nextHop tables
            %and set the meshRoute;
            for i=1:numRepeaters
                d2=sum((repmat(infrastructureLocations(i,:),numRepeaters,1)-infrastructureLocations).^2,2);
                [vals,indices]=sort(d2);  %pick the second smallest, because smallest is self!
                nextHop=repeaterIDs(indices(2));
                meshRoute.clientList = clientList{i};
                meshRoute.nextHop = nextHop;
                nodes{repeaterIDs(i)}.setMeshRouteTable(meshRoute);
            end
        end
        timeToRun = 1*3600;  %one hour
        timeToFinish = 60;  %how much time to stay quiet at the end to let things finish
        timeIncrement = 0.05;  %10 mSec
        poissonSendInterval = 1/0.06;
        pAckNeeded = 0.1;           %on average 10% of messages require ACK

        [sentPacketInfo,receivedPacketInfo] = runSimulation(nodes,timeToRun,...
            timeToFinish,timeIncrement,poissonSendInterval,pAckNeeded);
        thisStats = analyzeSimulationResults(sentPacketInfo,receivedPacketInfo);
        fprintf(1,'Stats for %d relays:\n',numRepeaters);
        disp(thisStats);
        stats{repIndex} = thisStats;
    end
    overallStats{modulatorIndex} = stats;
end