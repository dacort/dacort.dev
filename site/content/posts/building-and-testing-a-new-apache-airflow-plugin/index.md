---
title: "Building and Testing a new Apache Airflow Plugin"
date: 2021-07-09T11:30:00-07:00
# weight: 1
# aliases: ["/first"]
tags: ["airflow", "emr", "eks"]
showToc: true
# TocOpen: false
draft: false
# hidemeta: false
# comments: false
# disableHLJS: true # to disable highlightjs
# disableShare: false
# disableHLJS: false
# hideSummary: false
# searchHidden: true
# ShowReadingTime: true
# ShowBreadCrumbs: true
# ShowPostNavLinks: true
cover:
    image: "cover.jpg" # image path/url
    alt: "https://flic.kr/p/S3jt5j" # alt text
    relative: true # when using page bundles set this to true
    hidden: true # only hide on current single page
---

Recently, I had the opportunity to add a new EMR on EKS plugin to Apache Airflow. While I've been a consumer of Airflow over the years, I've never contributed directly to the project. And weighing in at over half a million lines of code, Airflow is a pretty complex project to wade into. So here's a guide on how I made a new operator in the AWS provider package. 

![](cloc.png)

## Overview

Before you get started, it's good to have an understanding of the different components of an Airflow task. The [Airflow Tasks documentation](https://airflow.apache.org/docs/apache-airflow/stable/concepts/tasks.html) covers two of the important aspects:

- Operators, predefined task templates to build DAGs
- Sensors, a subclass of Operators that wait on external services

[Hooks](https://airflow.apache.org/docs/apache-airflow/stable/concepts/connections.html#hooks) are also important in that they are the main interface to external services and often the building blocks that Operators are built out of.

All that said, in Airflow 1.0, [Plugins](https://airflow.apache.org/docs/apache-airflow/stable/plugins.html) were the primary way to integrate external features. That's changed in 2.0, and now there are sets of [Provider Packages](https://airflow.apache.org/docs/apache-airflow/stable/extra-packages-ref.html#providers-extras) that provide pip-installable packages for integrating with different providers. This includes cloud providers like AWS and GCP, as well as different APIs like Discord, Salesforce, and Slack. The [custom operators](https://airflow.apache.org/docs/apache-airflow/stable/howto/custom-operator.html) documentation is helpful, but it only discusses creating the operator - not how to test it, add documentation, update a provider package.

So...😅 once you have an understanding of how to add a new provider package and how it integrates, let's go over the steps we need to take to add a new plugin.

1. Add the Plugin Operator/Hook/Sensor/etc
2. Add tests(!!) for your new code
3. Create an example DAG
4. Add documentation in on how to use the Operator
5. Update the various sections of the provider.yaml
6. linting, checks, and linting again

_The official Airflow docs on [Community Providers](http://airflow.apache.org/docs/apache-airflow-providers/howto/create-update-providers.html) are also very helpful._

## Creating your new operator

All provider packages live in the [`airflow/providers`](https://github.com/apache/airflow/tree/main/airflow/providers) subtree of the git repository. 

![List of providers](provider_listing.png)

If you look in each provider directory, you'll see various directories including `hooks`, `operators`, and `sensors`. These provide some good examples of how to create your Operator.

For now, I'm going to create a new `emr_containers.py` file in each of the `hooks`, `operators`, and `sensors` directories. We'll be creating a new Hook for connecting to the [EMR on EKS API](https://docs.aws.amazon.com/emr-on-eks/latest/APIReference/Welcome.html), a new Sensor for waiting on jobs to complete, and an Operator that can be used to trigger your EMR on EKS jobs.

I won't go over the implementation details here, but you can take a look at each file in the Airflow repository.

One thing that was confusing to me during this process is that all three of those files have the same name...so at a glance, it was tough for me to know which component I was editing. But if you can keep this diagram in your head, it's pretty helpful.

![](emr_containers_workflow.png)

Note that there is no `EMRContainerSensor` in this workflow - that's because the default operator handles polling/waiting for the job to complete itself.

## Testing

Similar to the provider packages, tests for the provider packages live in the [`tests/providers`](https://github.com/apache/airflow/tree/main/tests/providers) subtree.

With the AWS packages, many plugins use the [moto](https://github.com/spulec/moto) library for testing, an AWS service mocking library. EMR on EKS is a fairly recent addition, so it's unfortunately not part of the mocking library. Instead, I used the standard `mock` library to return sample values from the API.

The tests are fairly standard unit tests, but what gets challenging is figuring how to actually *RUN* these tests. Airflow is a monorepo - there are many benefits and challenges to this approach, but what it means for us is we have to figure out how to run the whole smorgosboard of this project.

Luckily(!) Airflow has a cool CI environment known as [Breeze](https://github.com/apache/airflow/blob/main/BREEZE.rst) that can pretty much do whatever you need to make sure your new plugin is working well!

### Up and running with Breeze

The main challenge I had with Breeze was resource consumption. 🙁

[Breeze requires](https://github.com/apache/airflow/blob/main/BREEZE.rst#resources-required) a minimum of 4GB RAM for Docker and 40GB of free disk space. I had to tweak both of those settings on my mac, but even so I think Breeze is named for the winds that are kicked up by laptop fans everywhere when it starts. 😆

In any case, you _should_ be able to just type `./breeze` and be dropped into an Airflow shell after it builds a local version of the necessary Docker images.

### Unit tests

Once in the Airflow shell, you should be able to run any of your unit tests.

```shell
python -m pytest tests/providers/amazon/aws/operators/test_emr_containers.py
```

If you want, you can also run your tests with the `./breeze` CLI.

```shell
./breeze tests tests/providers/amazon/aws/sensors/test_emr_containers.py tests/providers/amazon/aws/operators/test_emr_containers.py tests/providers/amazon/aws/hooks/test_emr_containers.py
```

Now, let's make sure we have an example DAG to run.

## Integration Testing

### Example DAGs

It's crucial to provide an example DAG to show folks how to use your new Operator.

It's _also_ crucial to have an example DAG so you can make sure your Operator works!

For AWS, example DAGs live in `airflow/providers/amazon/aws/example_dags`. For testing, however, you'll need to copy or link your DAG into `files/dags`. When you run `breeze`, it will mount that directory and the DAG will be available to Airflow.

### Build your provider package

First, we need to build a local version of our provider package with the `prepare-provider-packages` command. 

_You may receive an error like `The tag providers-amazon/2.0.0 exists. Not preparing the package.` - if you do, you'll need to provide a suffix to the `prepare-provider-packages` command with the `-S` flag._

Then you can hop into Airflow

```shell
./breeze prepare-provider-packages amazon -S dev
./breeze start-airflow --use-airflow-version wheel --use-packages-from-dist
```

If you run `breeze` without the `start-airflow`, you'll just get dropped into a bash prompt and need to start the webserver and scheduler manually. I recommend just letting Breeze take care of that.

![](breeze_shell.png)

Once in the shell, you may need to create a user to be able to login to the Airflow UI.

```shell
airflow users create --role Admin --username admin --password admin --email admin@example.com --firstname foo --lastname bar
```

By default, port 28080 gets forward to Airflow so you should be able to browse to [http://localhost:28080](http://localhost:28080) and login as `admin`/`admin`.

![](airflow_dag_ui.png)

### Run your example DAG

In theory, you can Unpause your DAG in the UI and run it, but it's likely you need some environment variables.

With AWS, you'll need to define access credentials and region. You can create a new Connection to do this, or just do so in your Airflow shell.

Since we're working localy, we'll use temporary access keys, but in a production environment your Airflow workers should use [IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html).

_The following commands will all be executed in the `breeze` shell._

```shell
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_DEFAULT_REGION=us-east-1
```

Next, we'll try to run our example DAG using `airflow dags test`!

Our script requires the EMR on EKS virtual cluster ID and job role ARN, so we'll supply those as environment variables.

```shell
VIRTUAL_CLUSTER_ID=wfto7bwu9n8ajdohqkri06pc1 \
JOB_ROLE_ARN=arn:aws:iam::037238293423:role/emr_eks_default_role \
airflow dags test emr_eks_pi_job $(date -Is)
```

You should see the job spin up and display logs in your console.

![](emr_eks_dag_run.png)

And if you refresh the Airflow UI you should see a successful run! If not...it's time to debug.

## Documentation

OK! So...you've built your new Operator. You've written (and run) all your tests. Now it's time to help other folks use it!

The documentation was also a little bit tricky for me as it's in [reStructuredText](https://www.sphinx-doc.org/en/master/usage/restructuredtext/basics.html) format. I typically write in Markdown, so reST was a little foreign.

Fortunately, you can use `./breeze build-docs -- --package-filter apache-airflow-providers-amazon` to build the docs for a specific package.

Once you do that, the docs will be available in `docs/_build/docs/apache-airflow-providers-amazon/latest/index.html`. The links may not always work if you just open the file locally, but you should be able to make sure everything looks OK.

One awesome feature of reST is the ability to import snippets from other files and the Airflow docs make extensive use of this. For example, in my example DAG I have the following code:

```python
# [START howto_operator_emr_eks_env_variables]
VIRTUAL_CLUSTER_ID = os.getenv("VIRTUAL_CLUSTER_ID", "test-cluster")
JOB_ROLE_ARN = os.getenv("JOB_ROLE_ARN", "arn:aws:iam::012345678912:role/emr_eks_default_role")
# [END howto_operator_emr_eks_env_variables]
```

Note the `START` and `END` blocks. With those in there, I can include that snippet in my docs like so:

```rest
.. exampleinclude:: /../../airflow/providers/amazon/aws/example_dags/example_emr_eks_job.py
    :language: python
    :start-after: [START howto_operator_emr_eks_env_variables]
    :end-before: [END howto_operator_emr_eks_env_variables]
```

And then it'll show up in the docs like this - pretty sweet!

![](docs_import.png)

### `provider.yaml`

If you want your new Operator linked in the official provider docs, make sure to also update `provider.yaml` in the relevant provider.

## Merging

Now the ~~hard~~ easy part...getting your contribution merged in!

The official Airflow docs have a great section on the [contribution workflow](https://github.com/apache/airflow/blob/main/CONTRIBUTING.rst#contribution-workflow).

I think the main thing I struggled with were all the PR checks that happen automatically.

I couldn't figure out how to run them locally (and didn't learn about [`pre-commit`](https://github.com/apache/airflow/blob/main/STATIC_CODE_CHECKS.rst#id2) until after this process), so a lot of my workflow went like:

- commit locally
- git push
- wait for checks to fail
- dive into GitHub Actions output to see what failed
- fix locally
- GOTO start

That said, I'm _very_ happy there are so many checks in this project. There are a lot of things I didn't know about until the checks ran (like the `spelling_wordlist.txt` file) and it's great to have such a high level of automation to help contributors maintain the quality of their code.

## Wrapup

I want to send a quick shoutout to the folks in the [Airflow Slack community](https://apache-airflow-slack.herokuapp.com/) - they're all super nice and welcoming. And especially the folks that reviewed my PR, who were kind enough to not make _too_ much of my `BEEP BOOP` error message I had committed with my initial revision. 🤖 😆