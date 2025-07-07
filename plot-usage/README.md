# 3DCS Node Hour Usage Plotting
This workflow generates a plot of 3DCS node hour usage by user between specified start and end dates. It also logs the total usage and per-user usage for the given period.

### Functionality
#### Input Parameters:
- **Start Date:** The beginning of the time range for usage data (optional). If not provided, the plot starts from the earliest available data.
- **End Date:** The end of the time range for usage data (optional). If not provided, the plot extends to the latest available data.

#### Output
- A time-series plot of cumulative node hour usage per user, saved as `cumulative_usage_time_series.png`.
- Usage statistics (total and per-user) logged in the "Generate Plot" step.


### Plot Location
The generated plot is saved in the job directory at:
```
/pw/jobs/<workflow-name>/<job-number>/cumulative_usage_time_series.png
```

### Downloading the Plot
To download the plot:
- Navigate to the plot file in the editor page.
- Right-click the file (`cumulative_usage_time_series.png`).
- Select Download from the context menu.

