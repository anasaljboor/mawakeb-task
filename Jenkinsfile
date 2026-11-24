def AGENT_IMAGE = 'jenkins/inbound-agent:3395.v6e5377b_0fb_3c-5-jdk25'

def BUILD_POD = """
apiVersion: v1
kind: Pod
metadata:
  labels:
    beacon/role: build
spec:
  serviceAccountName: jenkins-agent
  automountServiceAccountToken: false
  nodeSelector:
    workload: builds
  tolerations:
    - key: dedicated
      operator: Equal
      value: builds
      effect: NoSchedule
  containers:
    - name: jnlp
      image: ${AGENT_IMAGE}
      resources:
        requests: {cpu: 200m, memory: 512Mi}
        limits: {cpu: "1", memory: 1Gi}
    - name: dind
      image: docker:29.5.3-dind
      args: ["--host=unix:///var/run/dind/docker.sock"]
      env:
        - {name: DOCKER_TLS_CERTDIR, value: ""}
      securityContext:
        privileged: true
      resources:
        requests: {cpu: "1", memory: 1536Mi}
        limits: {cpu: "3", memory: 3Gi}
      volumeMounts:
        - {name: dind-sock, mountPath: /var/run/dind}
        - {name: dind-storage, mountPath: /var/lib/docker}
    - name: docker
      image: docker:29.5.3-cli
      command: ["sleep"]
      args: ["infinity"]
      env:
        - {name: DOCKER_HOST, value: "unix:///var/run/dind/docker.sock"}
        - {name: BUILDX_GIT_INFO, value: "false"}
      resources:
        requests: {cpu: 100m, memory: 128Mi}
        limits: {cpu: 500m, memory: 512Mi}
      volumeMounts:
        - {name: dind-sock, mountPath: /var/run/dind}
    - name: trivy
      image: aquasec/trivy:0.76.2
      command: ["sleep"]
      args: ["infinity"]
      env:
        - {name: DOCKER_HOST, value: "unix:///var/run/dind/docker.sock"}
        - {name: TRIVY_CACHE_DIR, value: /trivy-cache}
      resources:
        requests: {cpu: 200m, memory: 512Mi}
        limits: {cpu: "2", memory: 2Gi}
      volumeMounts:
        - {name: dind-sock, mountPath: /var/run/dind}
        - {name: trivy-cache, mountPath: /trivy-cache}
  volumes:
    - {name: dind-sock, emptyDir: {}}
    - {name: dind-storage, emptyDir: {}}
    - name: trivy-cache
      persistentVolumeClaim:
        claimName: trivy-cache
"""

def DEPLOY_POD = """
apiVersion: v1
kind: Pod
metadata:
  labels:
    beacon/role: deploy
spec:
  serviceAccountName: beacon-deployer
  nodeSelector:
    workload: builds
  tolerations:
    - key: dedicated
      operator: Equal
      value: builds
      effect: NoSchedule
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile: {type: RuntimeDefault}
  containers:
    - name: jnlp
      image: ${AGENT_IMAGE}
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
      resources:
        requests: {cpu: 100m, memory: 256Mi}
        limits: {cpu: 500m, memory: 512Mi}
    - name: kubectl
      image: alpine/k8s:1.37.1
      command: ["sleep"]
      args: ["infinity"]
      env:
        - {name: HOME, value: /home/jenkins/agent}
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: {drop: ["ALL"]}
      resources:
        requests: {cpu: 100m, memory: 128Mi}
        limits: {cpu: 500m, memory: 256Mi}
"""

pipeline {
  agent none

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '30'))
    timeout(time: 45, unit: 'MINUTES')
    timestamps()
    skipDefaultCheckout(true)
  }

  stages {
    stage('Build, test, scan, publish') {
      agent {
        kubernetes {
          yaml BUILD_POD
          defaultContainer 'docker'
        }
      }
      stages {
        stage('1. Checkout') {
          steps {
            container('jnlp') {
              script {
                def scmVars = checkout scm
                env.GIT_COMMIT = scmVars.GIT_COMMIT
                env.GIT_URL = scmVars.GIT_URL
                env.SHORT_SHA = scmVars.GIT_COMMIT.substring(0, 12)
                env.IMAGE_TAG = "${env.IMAGE_REPO}:${env.SHORT_SHA}"
                currentBuild.description = "commit ${env.SHORT_SHA}"
              }
              sh 'git log -1 --format="commit:  %H%nauthor:  %an%ndate:    %cI%nsubject: %s"'
            }
            stash name: 'deploy-files', includes: 'scripts/**,k8s/**'
          }
        }

        stage('2. Build and test') {
          steps {
            sh '''
              for i in $(seq 1 60); do docker info >/dev/null 2>&1 && break; sleep 1; done
              docker info --format 'docker daemon {{.ServerVersion}} ({{.Architecture}})'
              mkdir -p reports/tests
              docker build --target test-results --output type=local,dest=reports/tests .
              docker build \
                --label org.opencontainers.image.revision="$GIT_COMMIT" \
                --label org.opencontainers.image.source="$GIT_URL" \
                -t "$IMAGE_TAG" .
            '''
          }
          post {
            always {
              junit allowEmptyResults: false, testResults: 'reports/tests/*.xml'
            }
          }
        }

        stage('3. Security scan') {
          steps {
            container('trivy') {
              sh 'sh scripts/scan.sh "$IMAGE_TAG" reports'
            }
            script {
              def v = readJSON file: 'reports/trivy-version.json'
              env.TRIVY_VERSION = "${v.Version}"
              env.TRIVY_DB_UPDATED = "${v.VulnerabilityDB?.UpdatedAt}"
              env.SCANNED_IMAGE_ID = readFile('reports/image-id.txt').trim()
              echo "Trivy ${env.TRIVY_VERSION}, vulnerability DB updated ${env.TRIVY_DB_UPDATED}, scanned image ${env.SCANNED_IMAGE_ID}"
            }
          }
          post {
            always {
              archiveArtifacts artifacts: 'reports/trivy.json, reports/trivy-version.json, reports/image-id.txt', allowEmptyArchive: true, fingerprint: true
            }
          }
        }

        stage('4. Publish') {
          steps {
            withCredentials([usernamePassword(credentialsId: 'registry', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_TOKEN')]) {
              sh '''
                echo "$REGISTRY_TOKEN" | docker login --username "$REGISTRY_USER" --password-stdin "$REGISTRY_SERVER"
                docker push "$IMAGE_TAG"
                docker logout "$REGISTRY_SERVER"
              '''
            }
            script {
              def repoDigest = sh(returnStdout: true, script: 'docker image inspect --format "{{index .RepoDigests 0}}" "$IMAGE_TAG"').trim()
              def digest = repoDigest.substring(repoDigest.indexOf('@') + 1)
              env.IMAGE_DIGEST = digest
              env.IMAGE_REF = "${env.IMAGE_REPO}@${digest}"
              echo "Published ${env.IMAGE_TAG}\nDigest    ${env.IMAGE_REF}"
            }
          }
        }
      }
    }

    stage('5. Promote via GitOps') {
      agent {
        kubernetes {
          yaml DEPLOY_POD
          defaultContainer 'kubectl'
        }
      }
      options {
        lock(resource: 'beacon-production')
        timeout(time: 15, unit: 'MINUTES')
      }
      steps {
        unstash 'deploy-files'
        script {
          env.PREVIOUS_IMAGE = sh(returnStdout: true, script: "kubectl get deployment beacon -n beacon -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true").trim()
          echo "Running now: ${env.PREVIOUS_IMAGE ?: '<none>'}\nPromoting:   ${env.IMAGE_REF}"
          def promote
          withCredentials([usernamePassword(credentialsId: 'gitops', usernameVariable: 'GITOPS_USER', passwordVariable: 'GITOPS_TOKEN')]) {
            promote = sh(returnStatus: true, script: '''
              COMMIT_MESSAGE="deploy $IMAGE_REF (jenkins build $BUILD_NUMBER, source commit $SHORT_SHA)" \
              SYNC_TIMEOUT=300 bash scripts/gitops-promote.sh "$IMAGE_REF"
            ''')
          }
          env.GITOPS_COMMIT = fileExists('gitops-commit.txt') ? readFile('gitops-commit.txt').trim() : ''
          if (promote == 3) {
            env.DEPLOY_RESULT = 'failed-gitops-push'
            error "Promotion of ${env.IMAGE_REF} failed: GitHub rejected the push to the GitOps repository. Nothing was promoted; production still runs ${env.PREVIOUS_IMAGE ?: '<none>'}. Check the gitops credential."
          }
          if (promote != 0) {
            env.DEPLOY_RESULT = 'failed-reverted-in-git'
            error "Promotion of ${env.IMAGE_REF} failed (ArgoCD sync/health or smoke test); GitOps commit ${env.GITOPS_COMMIT ?: '<none>'} reverted, previous image ${env.PREVIOUS_IMAGE ?: '<none>'} restored by ArgoCD."
          }
          env.DEPLOY_RESULT = 'success'
        }
      }
      post {
        always {
          script {
            def recordedAt = sh(returnStdout: true, script: 'date -u +%Y-%m-%dT%H:%M:%SZ').trim()
            writeJSON file: 'release.json', pretty: 2, json: [
              result         : env.DEPLOY_RESULT ?: 'failed',
              build          : env.BUILD_NUMBER,
              buildUrl       : env.BUILD_URL,
              commit         : env.GIT_COMMIT,
              image          : env.IMAGE_TAG,
              imageRef       : env.IMAGE_REF,
              digest         : env.IMAGE_DIGEST,
              gitopsRepo     : env.GITOPS_REPO,
              gitopsCommit   : env.GITOPS_COMMIT,
              previousImage  : env.PREVIOUS_IMAGE,
              trivyVersion   : env.TRIVY_VERSION,
              trivyDbUpdated : env.TRIVY_DB_UPDATED,
              recordedAt     : recordedAt
            ]
            sh 'cat release.json; kubectl get application beacon -n argocd || true'
          }
          archiveArtifacts artifacts: 'release.json', fingerprint: true
        }
      }
    }
  }

  post {
    success {
      echo "RELEASED commit ${env.SHORT_SHA} as ${env.IMAGE_REF}"
    }
    failure {
      echo "FAILED: commit ${env.SHORT_SHA ?: 'unknown'}; published=${env.IMAGE_REF ?: 'no'}; deploy=${env.DEPLOY_RESULT ?: 'not reached'}. See the failed stage above."
    }
  }
}
