#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEClient.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLEAddress serverAddress("30:c6:f7:27:e3:42"); // replace with the address of your server
BLEClient *pClient;
BLERemoteService *pRemoteService;

// Get the service and characteristic UUIDs
BLEUUID serviceUUID("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
BLEUUID characteristicUUID("da82c3d3-9f99-423f-9f33-3cd13f50c436");

bool fetchMessages = true;

bool scanForDevices(int duration)
{
  // Scan for BLE devices
  BLEScan *pScan = BLEDevice::getScan();
  pScan->setActiveScan(true);
  BLEScanResults scanResults = pScan->start(duration);
  BLEAdvertisedDevice advertisedDevice;
  for (int i = 0; i < scanResults.getCount(); i++)
  {
    advertisedDevice = scanResults.getDevice(i);
    if (advertisedDevice.getAddress() == serverAddress)
    {
      return true;
    }
  }
  Serial.println("Device not found");
  return false;
}

bool getService(BLUEUUID _serviceUUID)
{
  // Get a reference to the remote service
  pRemoteService = pClient->getService(_serviceUUID);
  if (pRemoteService == nullptr)
  {
    return false;
  }
  return true;
}

bool getCharacteristic(BLEUUID _characteristicUUID)
{
  // Get a reference to the remote characteristic
  BLERemoteCharacteristic *pRemoteCharacteristic = pRemoteService->getCharacteristic(characteristicUUID);
  if (pRemoteCharacteristic == nullptr)
  {
    Serial.println("Failed to find characteristic UUID");
    return false;
  }
  return true;
}

void setupClient()
{
  pClient = BLEDevice::createClient();

  Serial.print("Scanning for devices...");
  while (!scanForDevices(8))
  {
    Serial.print("...");
  }
  Serial.println("Device found");

  Serial.print("Connecting to server...");
  while (!(pClient->connect(serverAddress)))
  {
    Serial.print("...");
  }
  Serial.println("Connected");

  Serial.print("Getting service...");
  while (!getService(serviceUUID))
  {
    Serial.println(".");
  }
  Serial.println("Service found");

  Serial.print("Getting characteristic...");
  while (!getCharacteristic(characteristicUUID))
  {
    Serial.println(".");
  }
  Serial.println("Characteristic found");
  Serial.println("Done Setup");
}

void setup()
{
  Serial.begin(9600);
  BLEDevice::init("client");
  setupClient();
}

void loop()
{
  if (fetchMessages)
  {
    // Read the value of the characteristic
    std::string value = pRemoteCharacteristic->readValue();
    Serial.println(value.c_str());
    delay(1000);
  }
}
