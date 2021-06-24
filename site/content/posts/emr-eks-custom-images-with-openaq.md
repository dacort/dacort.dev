---
title: "Build your own Air Quality Monitor with OpenAQ and EMR on EKS"
date: 2021-06-24T21:20:00+00:00
tags: ["emr", "eks", "aws"]
draft: false
showToc: true
cover:
    image: "/images/posts-airq.png" # image path/url
    alt: "Example output of Air Quality Data" # alt text
    caption: "<text>" # display caption under cover
    relative: false # when using page bundles set this to true
    hidden: true # only hide on current single page
---

Fire season is closely approaching and as somebody that spent two weeks last year hunkered down inside with my browser glued to various air quality sites, I wanted to show how to use data from OpenAQ to build your own air quality analysis. 

With Amazon EMR on EKS, you can now [customize and package your own Apache Spark dependencies](https://aws.amazon.com/blogs/aws/customize-and-package-dependencies-with-your-apache-spark-applications-on-amazon-emr-on-amazon-eks/) and I use that functionality for this post.

## Overview

OpenAQ maintains a [publicly accessible dataset of various air quality metrics](https://registry.opendata.aws/openaq/) that's updated every half hour. [Bokeh](https://docs.bokeh.org/en/latest/index.html) is a popular library for Python data visualization. While it includes sample data for US county and state boundaries, we're going to use [shapefiles from census.gov](https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html).

We'll use an Apache Spark job on EMR on EKS to read the initial dataset from the S3 bucket, filter it for use case, and then combine it with the boundary data from census.gov in order to draw a map of the current air quality.

This post also shows how to use the custom containers support in EMR on EKS to build our own container image with the necessary dependencies.

## Pre-requisites

- An AWS account with access to Amazon Elastic Container Registry (ECR)
- An EMR on EKS cluster already setup
- Docker
- A container registry to push your image to

## Building the EMR on EKS Container Image

### Download the EMR base image

For this post, we'll be using the `us-west-2` region and EMR 6.3.0 release. Each region and release has a different base image URL, and you can find the full list [here](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/docker-custom-images-tag.html).

```shell
aws ecr get-login-password --region us-west-2 \
    | docker login --username AWS --password-stdin 895885662937.dkr.ecr.us-west-2.amazonaws.com

docker pull 895885662937.dkr.ecr.us-west-2.amazonaws.com/notebook-spark/emr-6.3.0:latest
```

### Customize the image

EMR on EKS comes with a variety of [default libraries](https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-studio-install-libraries-and-kernels.html) installed including plotly and seaborn, but we wanted to try out Bokeh for my illustration as they have a great [choropleth example](https://docs.bokeh.org/en/latest/docs/gallery/texas.html) and it's a library I've been hearing about occasionally. I was hoping to use Bokeh's `sampledata` for US and county, but I ended up using [GeoPandas](https://geopandas.org/) to re-project my map to a conic projection so Michigan wasn't squashed up against Wisconsin. :) GeoPandas makes it easy to read in shapefiles, so I just used the census.gov provided state and county data. 

Bokeh also uses Selenium and Chrome for it's static image generation, so we go ahead and install Chrome on the container image as well.

```dockerfile
FROM 895885662937.dkr.ecr.us-west-2.amazonaws.com/notebook-spark/emr-6.3.0:latest

USER root

# Install Chrome
RUN curl https://intoli.com/install-google-chrome.sh | bash && \
    mv /usr/bin/google-chrome-stable /usr/bin/chrome

# We need to upgrade pip in order to install pyproj
RUN pip3 install --upgrade pip

# If you pip install as root, use this
RUN pip3 install \
    bokeh==2.3.2 \
    boto3==1.17.93 \
    chromedriver-py==91.0.4472.19.0 \
    geopandas==0.9.0 \
    selenium==3.141.0 \
    shapely==1.7.1

RUN ln -s /usr/local/lib/python3.7/site-packages/chromedriver_py/chromedriver_linux64 /usr/local/bin/chromedriver

# Install bokeh sample data to /usr/local/share
RUN mkdir /root/.bokeh && \
    echo "sampledata_dir: /usr/local/share/bokeh" > /root/.bokeh/config && \
    bokeh sampledata

# Also install census data into the image :)
ADD https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_state_500k.zip  /usr/local/share/bokeh/
ADD https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_county_500k.zip /usr/local/share/bokeh/
RUN chmod 644 /usr/local/share/bokeh/cb*.zip

# This is a simple test to make sure generating the image works properly
COPY test /test/

USER hadoop:hadoop
```

### Build and push

Great, we've customized our image – now we just need to build and push it to a container registery somewhere! For this post, I chose GitHub but you can use any container registry like ECR or DockerHub.

_The below commands assume you have a GitHub Personal Access Token that has access to push images in the `CR_PAT` environment variable._

```shell
docker build -t emr-6.3.0-bokeh:latest .

export USERNAME=GH_USERNAME
echo $CR_PAT| docker login ghcr.io -u ${USERNAME} --password-stdin
docker tag emr-6.3.0-bokeh:latest ghcr.io/${USERNAME}/emr-6.3.0-bokeh:latest
docker push ghcr.io/${USERNAME}/emr-6.3.0-bokeh:latest
```

Great, now your image is ready to go! Let's look at the code we're going to use to generate our air quality map.


## Code walkthrough

If you already built your image, you can run the below code locally. In order to access S3 data, you'll have to set your `AWS_ACCESS_KEY_ID` and `AWS_SECRET_KEY_ID` environment variables.

```shell
docker run --rm -it --name airq-demo \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    emr-6.3.0-bokeh \
    pyspark --deploy-mode client --master 'local[1]'
```

### Reading and filtering OpenAQ Data

The first thing we need to do is read the the data for today's date into a Spark dataframe.

```python
import datetime

date = f"{datetime.datetime.utcnow().date()}"
df = spark.read.json(f"s3://openaq-fetches/realtime-gzipped/{date}/")
df.show()
```

```
+--------------------+---------------+---------+--------------------+-------+--------------------+--------------------+------+---------+-----------------+----------+-----+-----+
|         attribution|averagingPeriod|     city|         coordinates|country|                date|            location|mobile|parameter|       sourceName|sourceType| unit|value|
+--------------------+---------------+---------+--------------------+-------+--------------------+--------------------+------+---------+-----------------+----------+-----+-----+
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-13T22:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 25.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-13T23:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 16.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T00:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 18.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T01:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 23.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T02:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 23.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T03:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 21.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T04:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 20.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T05:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 16.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T06:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 17.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T07:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 18.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T08:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 20.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T09:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 26.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T10:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 29.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T11:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 34.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T12:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 33.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T13:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 40.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T14:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 39.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T15:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 41.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T16:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 50.0|
|[{EPA AirNow DOS,...|   {hours, 1.0}|Abu Dhabi|{24.424399, 54.43...|     AE|{2021-06-14T17:00...|US Diplomatic Pos...| false|     pm25|StateAir_AbuDhabi|government|µg/m³| 56.0|
+--------------------+---------------+---------+--------------------+-------+--------------------+--------------------+------+---------+-----------------+----------+-----+-----+
```

We can quickly see a few things:
1. Data is provided from all over the globe, we just want US
2. We have coordinates and country, but that's it for location data
3. There are multiple different types of readings
4. There are multiple different readings per day per location

```python
df.select('unit', 'parameter').distinct().sort("parameter").show()
```

```
+-----+---------+                                                               
| unit|parameter|
+-----+---------+
|µg/m³|       bc|
|µg/m³|       co|
|  ppm|       co|
|  ppm|      no2|
|µg/m³|      no2|
|µg/m³|       o3|
|  ppm|       o3|
|µg/m³|     pm10|
|µg/m³|     pm25|
|  ppm|      so2|
|µg/m³|      so2|
+-----+---------+
```

So, let's go ahead and filter down to the most recent PM2.5 reading in the United States.

To do that, it's a couple `where` filters and then we can utilize a window function (`last`) to get the last reading.

```python
# Filter down to US locations and PM2.5 readings only
usdf = (
    df.where(df.country == "US")
    .where(df.parameter == "pm25")
    .select("coordinates", "date", "parameter", "unit", "value", "location")
)

# Retrieve the most recent pm2.5 reading per county
from pyspark.sql.window import Window
from pyspark.sql.functions import last
windowSpec = (
    Window.partitionBy("location")
    .orderBy("date.utc")
    .rangeBetween(Window.unboundedPreceding, Window.unboundedFollowing)
)
last_reading_df = (
    usdf.withColumn("last_value", last("value").over(windowSpec))
    .select("coordinates", "last_value")
    .distinct()
)

last_reading_df.show()
```

We also only selected the `coordinates` and `last_value` columns as these are all we need at this point.

```
+--------------------+----------+                                               
|         coordinates|last_value|
+--------------------+----------+
|{38.6619, -121.7278}|       2.0|
| {41.9767, -91.6878}|       4.9|
|{39.54092, -119.7...|       8.0|
|{43.629605, -72.3...|       9.0|
|{46.8505, -111.98...|      10.0|
|{39.818715, -75.4...|       8.5|
+--------------------+----------+
```

### Mapping coordinates to counties

This was the most "fun" part of this journey. Bokeh provides some sample data and I initially just created a UDF that looked up the first county ID using the Polygon `intersects` method. Unfortunately, I then wanted to re-project the map to a conical projection (Albers). Bokeh's geo support isn't very strong, so I ended up looking at using GeoPandas to do the reprojection. That worked well, but the Bokeh county data wasn't in a format I could use with GeoPandas so I ended up downloading [Shapefiles from the Census Bureau](https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html).

So, we've got our `last_reading_df` dataframe. Lets map those coordinates to counties. The county data is relatively small (12mb zipped) so what I did was create a broadcast variable of `GEOID` -> `Geometry` mappings that could be used in a UDF to figure out if a PM2.5 reading is inside a specific county.

- Download the census data and create a broadcast variable

```python
import geopandas as gpd

COUNTY_URL = 'https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_county_500k.zip'

countydf = gpd.read_file(COUNTY_URL)
bc_county = sc.broadcast(dict(zip(countydf["GEOID"], countydf["geometry"])))

countydf.head()
```

We can see we're just mapping the `GEOID` column to the `geometry` column which is a polygon object containing the county boundaries.

```
  STATEFP COUNTYFP  COUNTYNS        AFFGEOID  GEOID       NAME          NAMELSAD STUSPS  STATE_NAME LSAD       ALAND     AWATER                                           geometry
0      21      141  00516917  0500000US21141  21141      Logan      Logan County     KY    Kentucky   06  1430224002   12479211  POLYGON ((-87.06037 36.68085, -87.06002 36.708...
1      36      081  00974139  0500000US36081  36081     Queens     Queens County     NY    New York   06   281594050  188444349  POLYGON ((-73.96262 40.73903, -73.96243 40.739...
2      34      017  00882278  0500000US34017  34017     Hudson     Hudson County     NJ  New Jersey   06   119640822   41836491  MULTIPOLYGON (((-74.04220 40.69997, -74.03900 ...
3      34      019  00882228  0500000US34019  34019  Hunterdon  Hunterdon County     NJ  New Jersey   06  1108086284   24761598  POLYGON ((-75.19511 40.57969, -75.19466 40.581...
4      21      147  00516926  0500000US21147  21147   McCreary   McCreary County     KY    Kentucky   06  1105416696   10730402  POLYGON ((-84.77845 36.60329, -84.73068 36.665...
```

- Create a UDF to find the county a coordinate is in

This just brute forces the list of GEOIDs/polygons and returns the first GEOID that intersects. There is likely a more elegant to do this. 

```python
from pyspark.sql.functions import udf
from pyspark.sql.types import StringType
from shapely.geometry import Point

def find_first_county_id(longitude: float, latitude: float):
    p = Point(longitude, latitude)
    for index, geo in bc_county.value.items():
        if geo.intersects(p):
            return index
    return None


find_first_county_id_udf = udf(find_first_county_id, StringType())
```

- Now we apply to the UDF to our `last_reading_df` dataframe

```python
# Find the county that this reading is from
mapped_county_df = last_reading_df.withColumn(
    "GEOID",
    find_first_county_id_udf(
        last_reading_df.coordinates.longitude, last_reading_df.coordinates.latitude
    ),
).select("GEOID", "last_value")
```

- And then finally we calculate the average PM2.5 value per county

```python
# Calculate the average reading per county
pm_avg_by_county = (
    mapped_county_df.groupBy("GEOID")
    .agg({"last_value": "avg"})
    .withColumnRenamed("avg(last_value)", "avg_value")
)

pm_avg_by_county.show(5)
```

```
+-----+------------------+                                                      
|GEOID|         avg_value|
+-----+------------------+
|31157|              16.0|
|49053|               3.0|
|26153|               6.9|
|36029|               1.1|
|42101|             10.66|
+-----+------------------+
```

Cool! So now we have a `GEOID` we can use in our GeoPandas dataframe and an average value of the most recent PM2.5 reading for that county. 

### Generating our Air Quality map

Now that we've got an average PM2.5 value per county, we need to join this with our map data and generate an image!

The first step is reading in US State and County shapefiles. We fetched these from census.gov while building the image and they're stored in `/usr/local/share/bokeh`. We also exclude any state not in the continental US.

```python
import geopandas as gpd

STATE_FILE = "file:///usr/local/share/bokeh/cb_2020_us_state_500k.zip"
COUNTY_FILE = "file:///usr/local/share/bokeh/cb_2020_us_county_500k.zip"
EXCLUDED_STATES = ["AK", "HI", "PR", "GU", "VI", "MP", "AS"]

county_df = gpd.read_file(COUNTY_FILE).query(f"STUSPS not in {EXCLUDED_STATES}")
state_df = gpd.read_file(STATE_FILE).query(f"STUSPS not in {EXCLUDED_STATES}")
```

Now we just do a simple `merge` on the GeoPandas dataframe, convert our maps to the Albers projection and save them as JSON objects.

```python
# Merge in our air quality data
county_aqi_df = county_df.merge(pm_avg_by_county.toPandas(), on="GEOID")

# Convert to a "proper" Albers projection :)
state_json = state_df.to_crs("ESRI:102003").to_json()
county_json = county_aqi_df.to_crs("ESRI:102003").to_json()
```

Now comes the fun part! Our data is all prepped, we've averaged the most recent data by county, and built a GeoJSON file of everything we need. Let's map it!

I won't go into the details of every line, but we'll make use of Bokeh's awesome `GeoJSONDataSource` functionality, add a `LinearColorMapper` that automatically shades the counties for us by the `avg_value` column using the `Reds9` palette, and adds a `ColorBar` on the right-hand side.

```python
from bokeh.models import ColorBar, GeoJSONDataSource, LinearColorMapper
from bokeh.palettes import Reds9 as palette
from bokeh.plotting import figure

p = figure(
    title="US Air Quality Data",
    plot_width=1100,
    plot_height=700,
    toolbar_location=None,
    x_axis_location=None,
    y_axis_location=None,
    tooltips=[
        ("County", "@NAME"),
        ("Air Quality Index", "@avg_value"),
    ],
)
p.grid.grid_line_color = None

# This just adds our state lines
p.patches(
    "xs",
    "ys",
    fill_alpha=0.0,
    line_color="black",
    line_width=0.5,
    source=GeoJSONDataSource(geojson=state_json),
)

# Add our county data and shade them based on "avg_value"
color_mapper = LinearColorMapper(palette=tuple(reversed(palette)))
color_column = "avg_value"
p.patches(
    "xs",
    "ys",
    fill_alpha=0.7,
    fill_color={"field": color_column, "transform": color_mapper},
    line_color="black",
    line_width=0.5,
    source=GeoJSONDataSource(geojson=county_json),
)

# Now add a color bar legend on the right-hand side
color_bar = ColorBar(color_mapper=color_mapper, label_standoff=12, width=10)
p.add_layout(color_bar, "right")
```

Finally, let's go ahead export the png!

```python
from bokeh.io import export_png
from bokeh.io.webdriver import create_chromium_webdriver

driver = create_chromium_webdriver(["--no-sandbox"])
export_png(p, filename="map.png", webdriver=driver)
```

Now, if you're running on a mac, you can just copy the generated map to your local system and open it up!

```shell
docker cp airq-demo:/home/hadoop/map.png .
open map.png
```

![Air Quality map](/images/posts-airq-map.png)

### Running on EMR on EKS

I've bundled this all up into a pyspark script in my `demo-code` repo. 

This demo assumes you already have an EMR on EKS virtual cluster up and running, you've built the image in the first part and pushed it to a container registry, and the IAM Role you use to run the job has access to both read and write to an S3 bucket.

First, download the `generate_aqi_map.py` code from the GitHub repo.

Then, upload that script to an S3 bucket you have access to.

```shell
aws s3 cp generate_aqi_map.py s3://<BUCKET>/code/
```

Now, just run your job! The pyspark script takes a few parameters:
- `<S3_BUCKET>` - The S3 bucket where you want to upload the generated image to
- `<PREFIX>` - The prefix in the bucket where you want the image located
- `--date 2021-01-01` (optional)  - A specific date for which you want to generate data for
    - Defaults to UTC today

```shell
export S3_BUCKET=<BUCKET_NAME>
export EMR_EKS_CLUSTER_ID=abcdefghijklmno1234567890
export EMR_EKS_EXECUTION_ARN=arn:aws:iam::123456789012:role/emr_eks_default_role
```


```shell
# Replace ghcr.io/OWNER/emr-6.3.0-bokeh:latest below with your image URL
aws emr-containers start-job-run \
    --virtual-cluster-id ${EMR_EKS_CLUSTER_ID} \
    --name openaq-conus \
    --execution-role-arn ${EMR_EKS_EXECUTION_ARN} \
    --release-label emr-6.3.0-latest \
    --job-driver '{
        "sparkSubmitJobDriver": {
            "entryPoint": "s3://'${S3_BUCKET}'/code/generate_aqi_map.py",
            "entryPointArguments": ["'${S3_BUCKET}'", "output/airq/"],
            "sparkSubmitParameters": "--conf spark.kubernetes.container.image=ghcr.io/OWNER/emr-6.3.0-bokeh:latest"
        }
    }' \
    --configuration-overrides '{
        "monitoringConfiguration": {
            "s3MonitoringConfiguration": { "logUri": "s3://'${S3_BUCKET}'/logs/" }
        }
    }'
```

```json
{
    "id": "0000000abcdefg12345",
    "name": "openaq-conus",
    "arn": "arn:aws:emr-containers:us-east-2:123456789012:/virtualclusters/abcdefghijklmno1234567890/jobruns/0000000abcdefg12345",
    "virtualClusterId": "abcdefghijklmno1234567890"
}
```

While the job is running, you can get the fetch the status of the job using the `emr-containers describe-job-run` command.

```shell
aws emr-containers describe-job-run \
    --virtual-cluster-id ${EMR_EKS_CLUSTER_ID} \
    --id 0000000abcdefg12345
```

Once the job is in the `COMPLETED` state, you should be able to copy the resulting image from your S3 bucket!

```shell
aws s3 cp s3://${S3_BUCKET}/output/airq/2021-06-24-latest.png .
```

And if you open that file, you'll get the most recent PM2.5 readings!

![Air Quality map](/images/posts-airq-map.png)

## Wrapup

Be sure to check out the [launch post](https://aws.amazon.com/blogs/aws/customize-and-package-dependencies-with-your-apache-spark-applications-on-amazon-emr-on-amazon-eks/) for more details, the documentation for [customing docker images for EMR on EKS](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/docker-custom-images.html), and my [demo video](https://youtu.be/0x4DRKmNPfQ).