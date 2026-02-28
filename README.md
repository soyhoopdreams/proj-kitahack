## Technical Implementation

### Technologies & Google Tools
Our architecture is designed to be lightweight, scalable, and rapidly deployable during a crisis. 

* **Frontend:** Flutter & Dart (Cross-platform deployment for iOS/Android).
* **AI Engine (Google Cloud):** Gemini 2.5 Flash via Vertex AI. Used for real-time computer vision (flood depth estimation) and NLP (context-aware survival instructions).
**Predictive Triggers (Google Flood Forecasting API):** Used to monitor potential flood risks and automate geofenced alerts when critical probability thresholds are met.
* **Mapping & Geolocation:** Google Maps SDK for Flutter & Google Routes API. Used to calculate dynamic rescue paths that actively avoid active disaster zones.
* **Backend & State:** Firebase (Firestore) for synchronized, real-time alert broadcasting across all active devices. 

### Explanation of Implementation (Architecture)
The system is built as a real-time, event-driven intelligence pipeline structured around three core layers:
1. **The Client Frontend:** A dual-interface system ("Civilian" and "Rescuer"). It manages local state efficiently, caching critical safety protocols so life-saving information remains accessible even if weather disrupts connectivity.
2. **The Intelligence Layer:** When a citizen uploads a photo of rising water, it bypasses standard databases and goes directly to Gemini 2.5 Flash. Gemini calculates water depth, and assigns a standardized hazard level. 
3. **The Synchronization & Routing Engine:** Once Gemini verifies a report, a `FloodAlert` is written to Firestore. The Google Maps SDK listens for these updates. When a new flood zone appears, the system passes the verified coordinates to the Google Maps Routes API, forcing the generation of safe detours around the hazard.

### Innovation
FloodMapr shifts disaster response from passive data consumption to active, AI-verified intelligence. We address three critical gaps in standard emergency tech:
* **Automated Visual Verification:** Traditional crowdsourcing relies on panicked human guesswork. Our system uses Gemini Vision to calculate hazard levels from environmental reference points (e.g., water against a vehicle tire) while automatically acting as a privacy shield by blurring personal data before public broadcast.
* **Context-Aware Guidance:** Victims in crisis do not have the cognitive bandwidth to read static PDF safety manuals. We replaced passive documents with an offline-capable AI Survival Chatbot that delivers immediate, conversational survival instructions grounded in official NADMA emergency protocols.
* **Dynamic Hazard Avoidance Routing:** Standard navigation apps (like Waze or standard Maps) blindly route vehicles into flooded roads because they prioritize the shortest distance. Our system utilizes custom **Polygon Exclusion** logic, mathematically forcing the Google Routes API to draw digital barriers around AI-verified flood zones, ensuring emergency responders are routed around danger.

### Challenges Faced
1.  **AI Severity Hallucinations:** Initially, Gemini struggled to quantify "severity," often flagging shallow puddles as life-threatening. We overcame this by engineering a strict "Rubric Prompt" that anchors severity scores (1-5) to physical visual cues (e.g., water reaching car tires vs. submerged roofs).
2.  **Dynamic Routing Complexities:** Integrating the Google Routes API to physically avoid polygon shapes on a map is mathematically heavy. To meet the hackathon deadline, we simulated the backend avoidance algorithm by plotting pre-calculated safe `Polylines` that dynamically spawn in response to the active `Markers` stored in our global `FloodState`.
3.  **State Management Collisions:** Merging independent features (GPS tracking, AI chat, and Firebase routing) caused significant state synchronization issues. We solved this by centralizing our memory into a `FloodState` singleton, ensuring the AI Chat History and Map Markers persist flawlessly even when the user switches between Civilian and Rescuer modes.

## Future Roadmap & Scalability
Our architecture was intentionally designed to be stateless and serverless, allowing it to scale effortlessly. Moving forward, our expansion strategy is phased across three horizons:

* **Phase 1: Smart City IoT Integration (Passive Monitoring):** Currently, our system relies on active crowdsourcing (citizens risking exposure to take photos). Our immediate next step is to partner with city councils to pipe their existing public traffic CCTV feeds directly into our Gemini/Vertex AI pipeline. This will enable passive, 24/7 monitoring of critical intersections, automatically triggering exclusion zones on our map the moment water pools.
* **Phase 2: Peer-to-Peer Mesh Networking:** Severe floods inevitably destroy cellular infrastructure. To ensure the app remains a functioning lifeline in disconnected zones, we plan to implement Bluetooth/Wi-Fi Direct mesh networking within our Flutter client. This will allow citizens' phones to pass AI-verified hazard markers and cached survival advice peer-to-peer.
* **Phase 3: Regional Geographic Expansion:** While built to solve Kuala Lumpur's flash floods, shifting monsoons affect the entire region. Within two years, we plan to deploy to other highly vulnerable Southeast Asian cities like Jakarta, Manila, and Bangkok. Because Google Maps and Gemini operate globally, scaling requires zero changes to our core backend as we will simply plug in localized weather APIs and update the AI’s knowledge base.
* **Enterprise Middleware (Google Cloud Run):** To handle massive traffic spikes during a regional super-storm, we will introduce an API Gateway via Google Cloud Functions or Cloud Run. This layer will queue, batch, and throttle user-uploaded image verification requests, preventing system-wide API rate-limiting and optimizing cloud costs.
