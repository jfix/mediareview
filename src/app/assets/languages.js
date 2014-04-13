    $( document ).ready(function() { 
        var options = {
            title: {}, 
            chart: {
                renderTo: 'container',
                type: 'bar'
            },
            legend: {
                enabled: false  
            },
            credits: {
                enabled: false
            },
            tooltip: {
                borderWidth: 0,
                borderRadius: 1
            },
            plotOptions: {
                series: {
                    allowPointSelect: true,
                    cursor: "pointer",
                    dataLabels: {
                        enabled: true,
                        align: 'left',
                        color: '#2f7ed8',
                        crop: false,
                        overflow: "none",
                        y: 0
                    
                    },
                    pointPadding: 0.1,
                    groupPadding: 0
                }
            },
            xAxis: {
                type: "category"
            },            
            yAxis: {
                title: {
                    text: "number of stories"
                }
            },
            series: [
                {
                    name: "# of stories in this language"
                }
            ]
        };
        
        $.getJSON('/api/languages', function(data) {

            options.series[0].data = data;
            options.title["text"] = "distribution of " + data.length + " languages";
            
            var chart = new Highcharts.Chart(options);
        });
        
    });
