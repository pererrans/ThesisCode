function [ nextSUPSHIFT ] = SupShiftChange(SUPSHIFT, price)
%update the supply shift according to the price
%SUPSHIFT ranges from 1 to 5. 

%the thresholds for the ROW incentive mines to enter and expand the ROW supply
%
Expand1 = 84; %60th percentile of the existing ROW supply curve
Expand2 = 96; %70th percentile of the existing ROW supply curve
Expand3 = 114; %80th percentile of the existing ROW supply curve

nextSUPSHIFT = SUPSHIFT; 

if(SUPSHIFT==1)
    if(price>=Expand1)
        nextSUPSHIFT = 2; 
    end
elseif(SUPSHIFT==2)
    if(price>=Expand2)
        nextSUPSHIFT = 3; 
    end
elseif(SUPSHIFT==3)
    if(price>=Expand3)
        nextSUPSHIFT = 4; 
    end
end    

end

