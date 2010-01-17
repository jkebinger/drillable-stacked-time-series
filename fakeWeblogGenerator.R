generateGrowingSequence = function(initialValue,length) {
  randomSequence = rlnorm(length-1,0.15,1/6);
  growingSequence = c(initialValue);
  for (i in 2:length)
  {
  	growingSequence = append(growingSequence,randomSequence[i-1] * growingSequence[i-1]);
  }	
  return(growingSequence);
}

generateFakeWeblog = function(controllers,actionsPerController,startDate,endDate)
{
	dateSeq = seq(as.Date(startDate), as.Date(endDate), "months");
	data = list();
	data$date = rep(dateSeq,controllers*actionsPerController);
	for (controllerIndex in 1:controllers)
	{
		for (actionIndex  in 1:actionsPerController)
		{
			data$controller = append(data$controller,rep(paste("controller",controllerIndex),length(dateSeq)));
			data$action = append(data$action,rep(paste("action",actionIndex),length(dateSeq)));
			data$hits = append(data$hits,generateGrowingSequence(100,length(dateSeq)));
		}	
		
	}
  data$hits = round(data$hits);
	return(data);
	
}


