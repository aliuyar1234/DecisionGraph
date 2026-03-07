FROM debian:bookworm-slim AS runtime

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV HOME=/app
ENV PHX_SERVER=true
ENV DECISION_GRAPH_DEPLOYMENT_ENV=prod

WORKDIR /app

COPY decisiongraph_beam ./

EXPOSE 4100

CMD ["bin/decisiongraph_beam", "start"]
