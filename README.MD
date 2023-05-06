# Azure Blob Storage Processing with Event Grid Triggers & Python Azure Functions 

The developers at Mystique Unicorn [process files][6] as soon [as they arrive][7]. They are facing issues with latencies at higher scale. They want to switch to an event-driven architecture with lower latencies to process files efficiently.

They heard about Azure's capabilities for event processing. Can you help them implement this event processing at Mystique Unicorn? 

![Miztiik Automation - Azure Blob Storage Processing with Event Grid Triggers & Python Azure Functions](images/miztiik_architecture_azure_blob_storage_processing_in_functions_even_grid_trigger_001.png)

## 🎯 Solution

Our solution enables seamless event processing on Azure Blob Storage through the use of Azure Functions and [Event Grid triggers][1]. Azure generates [blob storage events][2] for events like blob creation and deletion. A sample event from event grid is shown below,

```json
{
  "id": "538fcf9f-3..-1024-801417067d3a",
  "data": {
    "api": "PutBlob",
    "clientRequestId": "c0c0f290-ec..0bc9ef3b",
    "requestId": "538fcf9f-3..01417000000",
    "eTag": "0x8DB4E3BA4F8E488",
    "contentType": "application/json",
    "contentLength": 40,
    "blobType": "BlockBlob",
    "url": "https://warehouse6p5crf002.blob.core.windows.net/store-events-blob-002/source/7031_2023-05-06_event.json",
    "sequencer": "0000000000000000000000.000005276ba",
    "storageDiagnostics": { "batchId": "2901e730-b..-80d271000000" }
  },
  "topic": null,
  "subject": "/blobServices/default/containers/store-events-blob-002/blobs/source/7031_2023-05-06_event.json",
  "event_type": null
}
```
We can use this event as a trigger, retrieve the corresponding blob mentioned in `data.url` using the [input binding][3] and persist the processed event back to Blob Storage using the [output binding][4]. 

By leveraging the power of Bicep, all necessary resources can be easily provisioned and managed with minimal effort. Our solution uses Python for efficient event processing, allowing for quick and easy deployment of sophisticated event processing pipelines.

1. ## 🧰 Prerequisites

   This demo, instructions, scripts and bicep template is designed to be run in `westeurope`. With few or no modifications you can try it out in other regions as well(_Not covered here_).

   - 🛠 Azure CLI Installed & Configured - [Get help here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
   - 🛠 Bicep Installed & Configured - [Get help here](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
   - 🛠 VS Code & Bicep Extenstions - [Get help here](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#vs-code-and-bicep-extension)

1. ## ⚙️ Setting up the environment

   - Get the application code

     ```bash
     https://github.com/miztiik/azure-blob-eventgrid-trigger-function
     cd azure-blob-eventgrid-trigger-function
     ```

1. ## 🚀 Prepare the environment

   Let check you have Azure Cli working with 

    ```bash
      # You should have azure cli preinstalled
      az account show
    ```

    You should see an output like this,

   ```json
    {
      "environmentName": "AzureCloud",
      "homeTenantId": "16b30820b6d3",
      "id": "1ac6fdbff37cd9e3",
      "isDefault": true,
      "managedByTenants": [],
      "name": "YOUR-SUBS-NAME",
      "state": "Enabled",
      "tenantId": "16b30820b6d3",
      "user": {
        "name": "miztiik@",
        "type": "user"
      }
    }
   ```

1. ## 🚀 Deploying the application

   - **Stack: Main Bicep**
     This will create the following resoureces
     - General purpose Storage Account
        - This will be used by Azure functions to store the function code
     - Storage Account with blob container
        - This will be used to store the events
     - Event Grid Topic
        - This will be used to trigger the Azure Function.
        - Create a subscription to the topic, that [filters][5] for `Microsoft.Storage.BlobCreated` events specific to the blob container.
     - Python Azure Function
        - Input, Trigger, Output Binding to the blob container for events

      ```bash
      # make deploy
      sh deployment_scripts/deploy.sh
      ```

      After successfully deploying the stack, Check the `Resource Groups/Deployments` section for the resources.
      
      ![Miztiik Automation - Azure Blob Storage Processing with Event Grid Triggers & Python Azure Functions](images/miztiik_architecture_azure_blob_storage_processing_in_functions_even_grid_trigger_002.png)



1. ## 🔬 Testing the solution

   - **Upload file(s) to blob**

      Get the storage account and container name from the output of the deployment. Upload a file to the container and check the logs of the function app to see the event processing in action.

      Sample bash script to upload files to blob container. You can also upload manually from the portal,
      ```bash
      # Set variables
      RESOURCE_GROUP="Miztiik_Enterprises_azure_blob_eventgrid_trigger_function_002"
      LOCATION="northeurope"
      SA_NAME="warehouse6p5crf002"
      CONTAINER_NAME="store-events-blob-002"

      for i in {1..2}
      do
      FILE_NAME_PREFIX=$(openssl rand -hex 4)
      FILE_NAME="${RANDOM}_$(date +'%Y-%m-%d')_event.json"
      echo -n "{\"message\": \"hello world on $(date +'%Y-%m-%d')\" , \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > ${FILE_NAME} 
      az storage blob upload \
        --account-name ${SA_NAME} \
        --container-name ${CONTAINER_NAME} \
        --name "source/${FILE_NAME}" \
        --file ${FILE_NAME} \
        --auth-mode login
      
      sleep 2
      echo -e "\n\n---> ${FILE_NAME} uploaded to ${CONTAINER_NAME} in ${SA_NAME} storage account\n\n"
      done
      ```
      You should see an output like this,
      >---> 27999_2023-05-06_event.json uploaded to store-events-blob-002 in warehouse6p5crf002 storage account
       
      ![Miztiik Automation - Azure Blob Storage Processing with Event Grid Triggers & Python Azure Functions](images/miztiik_architecture_azure_blob_storage_processing_in_functions_even_grid_trigger_003.png)

      ![Miztiik Automation - Azure Blob Storage Processing with Event Grid Triggers & Python Azure Functions](images/miztiik_architecture_azure_blob_storage_processing_in_functions_even_grid_trigger_004.png)

     
1. ## 📒 Conclusion

    Here we have demonstrated trigger Azure functions with http trigger and process blob files. You can extend the solution and configure the function to send the events to other services like Event Hub, Service Bus, or persist them to Cosmos etc.
  

1. ## 🧹 CleanUp

If you want to destroy all the resources created by the stack, Execute the below command to delete the stack, or _you can delete the stack from console as well_

- Resources created during [Deploying The Application](#-deploying-the-application)
- _Any other custom resources, you have created for this demo_

```bash
# Delete from resource group
az group delete --name Miztiik_Enterprises_xxx --yes
# Follow any on-screen prompt
```

This is not an exhaustive list, please carry out other necessary steps as maybe applicable to your needs.

## 📌 Who is using this

This repository aims to show how to Bicep to new developers, Solution Architects & Ops Engineers in Azure.


### 💡 Help/Suggestions or 🐛 Bugs

Thank you for your interest in contributing to our project. Whether it is a bug report, new feature, correction, or additional documentation or solutions, we greatly value feedback and contributions from our community. [Start here](/issues)

### 👋 Buy me a coffee

[![ko-fi](https://www.ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/Q5Q41QDGK) Buy me a [coffee ☕][900].

### 📚 References


1. [Azure Event Grid trigger for Azure Functions][1]
1. [Blob Storage events][2]
1. [Azure Blob Storage Input Binding][3]
1. [Azure Blob Storage Ouput Binding][4]
1. [Azure Event Grid Filters][5]
1. [Miztiik Blog - Blob Storage Event Processing with Python Azure Functions][6]
1. [Miztiik Blog - Blob Storage Processing with Python Azure Functions with HTTP Triggers][7]



[1]: https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-grid-trigger?tabs=in-process%2Cextensionv3&pivots=programming-language-python
[2]: https://learn.microsoft.com/en-us/azure/event-grid/event-schema-blob-storage?tabs=event-grid-event-schema#blob-storage-events
[3]: https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-input?tabs=python-v1
[4]: https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-storage-blob-output?tabs=python-v1
[5]: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blob-event-overview
[6]: https://github.com/miztiik/azure-blob-trigger-python-function
[7]: https://github.com/miztiik/azure-blob-input-binding-to-function

### 🏷️ Metadata

![miztiik-success-green](https://img.shields.io/badge/Miztiik:Automation:Level-200-blue)

**Level**: 200


[100]: https://www.udemy.com/course/aws-cloud-security/?referralCode=B7F1B6C78B45ADAF77A9
[101]: https://www.udemy.com/course/aws-cloud-security-proactive-way/?referralCode=71DC542AD4481309A441
[102]: https://www.udemy.com/course/aws-cloud-development-kit-from-beginner-to-professional/?referralCode=E15D7FB64E417C547579
[103]: https://www.udemy.com/course/aws-cloudformation-basics?referralCode=93AD3B1530BC871093D6
[899]: https://www.udemy.com/user/n-kumar/
[900]: https://ko-fi.com/miztiik
[901]: https://ko-fi.com/Q5Q41QDGK