# Observability

Getting insight into pod logs a la Azure Application Insight.

Stack:
- Fluent Bit: Deploys DaemonSet per node to collect logs
- Loki: Stores logs in a time series database
- Grafana: Visualizes logs
