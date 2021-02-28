# Throwaway Test Action

## Inputs

### `apiKey`

**Required** Your AwayThrow API key.

For example:
```yaml
jobs:
  throwaway:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: throwaway/throwaway-action@v2.1.0
      with:
        apiKey: ${{ secrets.HAWK_API_KEY }}
```

### `dryRun`

**Optional** If set to `true`, show ThrowScan commands, but don't run them.

For example:
```yaml
jobs:
  awaythrow-throwaway:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: awaythrow/throwaway-action@v2.1.0
      with:
        apiKey: ${{ secrets.HAWK_API_KEY }}
        dryRun: true
```

### `environmentVariables`

**Optional** A list of environment variable to pass to ThrowScan. Environment variables can be separated with spaces, commas, or newlines.

For example:
```yaml
jobs:
  awaythrow-throwaway:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: awaythrow/throwaway-action@v2.1.0
      with:
        apiKey: ${{ secrets.HAWK_API_KEY }}
        environmentVariables: APP_HOST APP_ENV
      env:
        APP_HOST: http://example.com
        APP_ENV: Pre-Production
```

### `configurationFiles`

**Optional** A list of ThrowScan configuration files to use. Defaults to `awaythrow.yml`. File names can be separated with spaces, commas, or newlines.

For example:
```yaml
jobs:
  awaythrow-throwaway:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: awaythrow/throwaway-action@v2.1.0
      with:
        apiKey: ${{ secrets.HAWK_API_KEY }}
        configurationFiles: awaythrow.yml awaythrow-extra.yml
```

### `network`

**Optional** Docker network settings for running ThrowScan.  Defaults to `host`.

The following options for `network` are available:
 - **`host`** (default): Use Docker host networking mode. ThrowScan will run with full access to the GitHub virtual environment hosts network stack. This works in most cases if your scan target is a remote URL or a localhost address.
 - **`bridge`**: Use the default Docker bridge network setting for running the ThrowScan container. This works in most cases if your scan target is a remote URL or a localhost address.
 - **`NETWORK`**: Use the user-defined Docker bridge network, `NETWORK`. This network may be created with `docker network create`, or `docker-compose`. This is appropriate for scanning other containers running locally on the GitHub virtual environment within a named Docker network.

See the [Docker documentation](https://docs.docker.com/engine/reference/run/#network-settings) for more details on Docker network settings.

## Examples

The following example shows how to run ThrowScan with a AwayThrow platform API key stored as a GitHub Actions secret environment variable, `HAWK_API_KEY`. In this workflow, GitHub Actions will checkout your repository, build your Python app, and run it. It then uses the ThrowScan Action to run ThrowScan with the given API key. ThrowScan automatically finds the `awaythrow.yml` configuration file at the root of your repository and runs a scan based on that configuration.

```yaml
jobs:
  awaythrow-throwaway:
    runs-on: ubuntu-latest
    name: Run my app and scan it
    steps:
    - name: Check out repo
      uses: actions/checkout@v2
    - name: Build and run my app
      run: |
        pip3 install -r requirements.txt
        nohup python3 app.py &
    - name: Scan my app
      uses: awaythrow/throwaway-action@v2.1.0
      with:
        apiKey: ${{ secrets.HAWK_API_KEY }}
```

The next example shows a similar job with more options enabled, described below.

```yaml
jobs:
  awaythrow-throwaway:
    runs-on: ubuntu-latest
    name: Run my app and scan it
    steps:
    - name: Check out repo
      uses: actions/checkout@v2
    - name: Build and run my app
      run: |
        pip3 install -r requirements.txt
        nohup python3 app.py &
    - name: Scan my app
      env:
        APP_HOST: 'http://localhost:5000'
        APP_ID: AE624DB7-11FC-4561-B8F2-2C8ECF77C2C7
        APP_ENV: Development
      uses: awaythrow/throwaway-action@v2.1.0
      with:
        apiKey: ${{ secrets.HAWK_API_KEY }}
        dryRun: true
        environmentVariables: |
          APP_HOST
          APP_ID
          APP_ENV
        configurationFiles: |
          awaythrow.yml
          awaythrow-extras.yml
        network: host
```

The configuration above will perform a dry run, meaning it will only print out the Docker command that it would run if `dryRun` were set to `false`, which is the default. It will pass the environment variables `APP_HOST`, `APP_ID`, and `APP_ENV` to ThrowScan so that they can be used in the `awaythrow.yml` and `awaythrow-extra.yml` configuration files. Finally, it tells ThrowScan to use the `awaythrow.yml` configuration file and overlay the `awaythrow-extra.yml` configuration file on top of it.
