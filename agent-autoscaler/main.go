package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/gin-gonic/gin"
	"github.com/imroc/req/v3"
	log "github.com/sirupsen/logrus"
	ginlogrus "github.com/toorop/gin-logrus"
)

type Agent struct {
	Name string `json:"name"`
}

type Jobs struct {
	Count int   `json:"count"`
	Value []Job `json:"value"`
}

type Job struct {
	FinishTime  *string `json:"finishTime"`
	ReceiveTime *string `json:"receiveTime"`
	Agents      []Agent `json:"matchedAgents"`
}

type State string

const (
	// running
	PROVISIONING State = "PROVISIONING" // resources are allocated for the VM. The VM is not running yet.
	STAGING      State = "STAGING"      // resources are acquired, and the VM is preparing for first boot.
	RUNNING      State = "RUNNING"      // the VM is booting up or running.
	// stopped
	STOPPING   State = "STOPPING"   // the VM is being stopped. You requested a stop, or a failure occurred. This is a temporary status after which the VM enters the TERMINATED status.
	SUSPENDING State = "SUSPENDING" // the VM is in the process of being suspended. You suspended the VM.
	SUSPENDED  State = "SUSPENDED"  // the VM is in a suspended state. You can resume the VM or delete it.
	TERMINATED State = "TERMINATED" // the VM is stopped. You stopped the VM, or the VM encountered a failure. You can restart or delete the VM.
	// should result in running state
	REPAIRING State = "REPAIRING" // the VM is being repaired. Repairing occurs when the VM encounters an internal error or the underlying machine is unavailable due to maintenance. During this time, the VM is unusable. You are not billed when a VM is in repair. VMs are not covered by the Service level agreement (SLA) while they are in repair. If repair succeeds, the VM returns to one of the above states.
	Unknown   State = "unknown"
)

func (s State) isStopped() bool {

	return s == STOPPING || s == SUSPENDING || s == SUSPENDED || s == TERMINATED
}

func (s State) isRunning() bool {

	return s == PROVISIONING || s == STAGING || s == RUNNING || s == REPAIRING
}

func (j Job) belongsToAgent(name string) bool {

	for _, agent := range j.Agents {
		if agent.Name == name {
			return true
		}
	}
	return false
}

func (j Job) waiting() bool {

	return j.FinishTime == nil && j.ReceiveTime == nil
}

func (j Job) running() bool {

	return j.FinishTime == nil && j.ReceiveTime != nil
}

func (j Job) completed() bool {

	return j.FinishTime != nil
}

var projectId = ""
var zone = ""
var isDebug = false

const API_VERSION = "6.0"

var azureClient = newHttpClient()
var computeClient = newComputeClient()

func getEnvDefault(name string, defaultValue string) string {

	if val, ok := os.LookupEnv(name); ok {
		return val
	}
	return defaultValue
}

type InstanceClient struct {
	*compute.InstancesClient
}

func newComputeClient() *InstanceClient {

	if client, err := compute.NewInstancesRESTClient(context.Background()); err != nil {
		panic(err)
	} else {
		return &InstanceClient{client}
	}
}

func getObservedAgents() (ret map[string]int) {

	ret = map[string]int{}
	for _, v := range strings.Split(getEnvDefault("AGENTS", ""), ",") {
		ret[v] = 0
	}
	return
}

func (c *InstanceClient) getInstanceState(ctx context.Context, instanceName string) (State, error) {

	if res, err := c.Get(ctx, &computepb.GetInstanceRequest{
		Project:  projectId,
		Zone:     zone,
		Instance: instanceName,
	}); err != nil {
		log.Errorf("Could not get status for instance: %s - %s", instanceName, err.Error())
		return Unknown, err
	} else if res.Status == nil {
		log.Errorf("Could not read status for instance: %s", instanceName)
		return Unknown, fmt.Errorf("instance status is unknown")
	} else {
		return (State)(*res.Status), nil
	}
}

// blocking until instance started or failed to start
func (c *InstanceClient) startInstance(ctx context.Context, instanceName string) error {

	log.Infof("About to start instance: %s", instanceName)
	if res, err := c.Start(ctx, &computepb.StartInstanceRequest{
		Project:  projectId,
		Zone:     zone,
		Instance: instanceName,
	}); err != nil {
		log.Errorf("Could not start instance: %s - %s", instanceName, err.Error())
		return err
	} else {
		if err := res.Wait(ctx); err != nil {
			log.Errorf("Failed to wait for instance to start: %s", err.Error())
			return err
		} else {
			log.Infof("Started instance: %s", instanceName)
		}
	}
	return nil
}

// blocking until instance started or failed to start
func (c *InstanceClient) stopInstance(ctx context.Context, instanceName string) error {

	log.Infof("About to stop instance: %s", instanceName)
	if res, err := c.Stop(ctx, &computepb.StopInstanceRequest{
		Project:  projectId,
		Zone:     zone,
		Instance: instanceName,
	}); err != nil {
		log.Errorf("Could not stop instance: %s - %s", instanceName, err.Error())
		return err
	} else {
		if err := res.Wait(ctx); err != nil {
			log.Errorf("Failed to wait for instance to stop: %s", err.Error())
			return err
		} else {
			log.Infof("Stopped instance: %s", instanceName)
		}
	}
	return nil
}

func newHttpClient() *req.Client {

	client := req.C()
	client.SetUserAgent("g-spot-agents-poll")
	client.SetCommonBasicAuth("", getEnvDefault("AZURE_PAT", ""))
	client.SetCommonHeader("Accept", "application/json")
	client.SetBaseURL(fmt.Sprintf("https://dev.azure.com/%s/_apis/distributedtask/", getEnvDefault("AZURE_ORGANIZATION", "")))
	client.SetCommonQueryParam("api-version", API_VERSION).SetTimeout(30 * time.Second)
	if isDebug {
		client.EnableDumpAll()
	}
	return client
}

func handlePoll(ctx *gin.Context) {

	log.Info("Starting poll cycle")
	jobs := Jobs{}
	if resp, err := azureClient.R().SetContext(ctx).SetSuccessResult(&jobs).Get(fmt.Sprintf("pools/%s/jobrequests", getEnvDefault("AZURE_POOL_ID", ""))); err != nil {
		log.Errorf("Poll request failed: %s", err.Error())
		ctx.AbortWithError(http.StatusInternalServerError, err)
	} else if resp.IsErrorState() {
		log.Errorf("Poll request unsuccessful: %s", resp.Status)
		ctx.AbortWithError(http.StatusInternalServerError, fmt.Errorf(resp.Status))
	} else if resp.IsSuccessState() {
		observedAgents := getObservedAgents()
		for _, job := range jobs.Value {
			if !job.completed() {
				for _, agent := range job.Agents {
					if _, ok := observedAgents[agent.Name]; ok {
						log.Infof("Found queued job for agent pool assigned to agent(s): %v", job.Agents)
						observedAgents[agent.Name] += 1
					} else {
						log.Warnf("Found queued job using an agent (\"%s\") that is not configured for observation", agent.Name)
					}
				}
			}
		}
		for agent, jobCount := range observedAgents {
			if jobCount > 0 {
				if state, _ := computeClient.getInstanceState(ctx, agent); state.isStopped() {
					computeClient.startInstance(ctx, agent)
				}
			} else {
				if state, _ := computeClient.getInstanceState(ctx, agent); state.isRunning() {
					computeClient.stopInstance(ctx, agent)
				}
			}
		}
	}
	log.Info("Finished poll cycle")
	ctx.Status(http.StatusOK)
}

func handleWebhook(ctx *gin.Context) {

	if body, err := io.ReadAll(ctx.Request.Body); err != nil {
		log.Errorf("Error receiving webhook: %s", err.Error())
		ctx.AbortWithError(http.StatusBadRequest, err)
	} else {
		log.Info("Received webhook")
		log.Info(string(body))
		ctx.Status(http.StatusOK)
	}
}

func main() {

	log.Info("Starting poll server")

	projectId = getEnvDefault("PROJECT_ID", "default")
	zone = getEnvDefault("ZONE", "unknown")

	if _, ok := os.LookupEnv("DEBUG"); ok {
		log.Info("Debug mode active")
		isDebug = ok
	}

	if len(getObservedAgents()) <= 0 {
		log.Warn("No agent was given - no spot instance will be started/stopped")
	}

	authInterceptor := gin.BasicAuth(gin.Accounts{
		getEnvDefault("AUTH_USER", "ci_user"): getEnvDefault("AUTH_PASSWORD", projectId),
	})

	engine := gin.New()
	engine.Use(ginlogrus.Logger(log.WithFields(log.Fields{})))
	engine.GET(getEnvDefault("ROUTE_POLL", "/poll"), authInterceptor, handlePoll)
	engine.POST(getEnvDefault("ROUTE_WEBHOOK", "/webhook"), authInterceptor, handleWebhook)
	engine.GET("/healthcheck", func(ctx *gin.Context) { ctx.Status(http.StatusOK) })
	engine.Run("0.0.0.0:" + getEnvDefault("PORT", "8080"))
}
