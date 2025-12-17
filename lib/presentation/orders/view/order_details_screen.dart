import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:oradosales/presentation/orders/provider/order_details_provider.dart';
import 'package:oradosales/presentation/orders/provider/order_provider.dart';
import 'package:oradosales/presentation/orders/provider/order_response_controller.dart';
import 'package:oradosales/presentation/orders/view/task_details.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

// ---------------- STATUS MAP + ENUM ---------------- //

final Map<DeliveryStage, String> _statusAPIMap = {
  DeliveryStage.awaitingStart: "awaiting_start",
  DeliveryStage.goingToPickup: "start_journey_to_restaurant",
  DeliveryStage.atPickup: "reached_restaurant",
  DeliveryStage.goingToCustomer: "picked_up",
  DeliveryStage.outForDelivery: "out_for_delivery",
  DeliveryStage.reachedCustomer: "reached_customer",
  DeliveryStage.completed: "delivered",
};

// Delivery stage flow
enum DeliveryStage {
  awaitingStart,
  notStarted,
  goingToPickup, // start_journey_to_restaurant
  atPickup, // reached_restaurant
  goingToCustomer, // picked_up
  outForDelivery, // out_for_delivery
  reachedCustomer, // reached_customer
  completed, // delivered
}
DeliveryStage mapBackendStatus(String status) {
  switch (status) {
    case "awaiting_start":
      return DeliveryStage.awaitingStart;

    case "start_journey_to_restaurant":
      return DeliveryStage.goingToPickup;

    case "reached_restaurant":
      return DeliveryStage.atPickup;

    case "picked_up":
      return DeliveryStage.goingToCustomer;

    case "out_for_delivery":
      return DeliveryStage.outForDelivery;

    case "reached_customer":
      return DeliveryStage.reachedCustomer;

    case "delivered":
      return DeliveryStage.completed;

    default:
      return DeliveryStage.notStarted;
  }
}

enum ActiveSection { pickup, delivery }


// ---------------- WIDGET ---------------- //

class OrderDetailsBottomSheet extends StatefulWidget {
  final String orderId;

  const OrderDetailsBottomSheet({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<OrderDetailsBottomSheet> createState() =>
      _OrderDetailsBottomSheetState();
}

class _OrderDetailsBottomSheetState extends State<OrderDetailsBottomSheet> {
  GoogleMapController? _mapController;

  LatLng? _shopLatLng;
  LatLng? _deliveryLatLng;
  LatLng? _agentLatLng;

  Marker? _shopMarker;
  Marker? _customerMarker;
  Marker? _agentMarker;

  Set<Polyline> _polylines = {};

  bool _mapReady = false;
  bool _staticMapInitialized = false;

  StreamSubscription<Position>? _positionStreamSubscription;

  // ---- Slide button + stages ----
  DeliveryStage _stage = DeliveryStage.notStarted;
  double _slideProgress = 0.0; // 0 → 1
  bool _isSliding = false; // Prevent stage from being overwritten during slide
  bool _hasRespondedToOrder = false; // Hide buttons immediately after response
  bool _pickupCompleted = false; // sticky once picked_up is reached
  ActiveSection _activeSection = ActiveSection.pickup;

  // Scroll targets for sections
  final GlobalKey _pickupSectionKey = GlobalKey();
  final GlobalKey _arrivalSectionKey = GlobalKey();
  final GlobalKey _deliverySectionKey = GlobalKey();

  int _stageRank(DeliveryStage s) {
    switch (s) {
      case DeliveryStage.awaitingStart:
      case DeliveryStage.notStarted:
        return 0;
      case DeliveryStage.goingToPickup:
        return 1;
      case DeliveryStage.atPickup:
        return 2;
      case DeliveryStage.goingToCustomer: // picked_up
        return 3;
      case DeliveryStage.outForDelivery:
        return 4;
      case DeliveryStage.reachedCustomer:
        return 5;
      case DeliveryStage.completed:
        return 6;
    }
  }

  bool _isPickupStageOrBeyond(DeliveryStage s) =>
      _stageRank(s) >= _stageRank(DeliveryStage.goingToCustomer);

  Future<void> _scrollToSection(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        print("🔥 BottomSheet INIT");
    print("🔥 OrderId = ${widget.orderId}");
    print("🔥 Provider available = true");

    context.read<OrderDetailController>().loadOrderDetails(widget.orderId);
      _startAgentLocationUpdates();
    });
  }

  @override
void dispose() {
  _mapController?.dispose();
  _positionStreamSubscription?.cancel();
  super.dispose();
}

  // ---------------- LIVE LOCATION ---------------- //

  Future<void> _startAgentLocationUpdates() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!mounted) return;

        _agentLatLng = LatLng(position.latitude, position.longitude);
      _updateAgentOnMap();
      });
  }

  void _updateAgentOnMap() {
    if (!_mapReady || _agentLatLng == null) return;

    setState(() {
      _agentMarker = Marker(
        markerId: const MarkerId('agent'),
        position: _agentLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: const InfoWindow(title: "Your Location"),
      );

      _polylines
          .removeWhere((p) => p.polylineId.value == 'agent_to_restaurant');

      if (_shopLatLng != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('agent_to_restaurant'),
            color: Colors.green,
            width: 3,
            points: [_agentLatLng!, _shopLatLng!],
            patterns: [PatternItem.dash(15), PatternItem.gap(5)],
          ),
        );
      }
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(_agentLatLng!),
    );
  }

  // ---------------- MAP INIT ---------------- //

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapReady = true;
    _tryInitializeStaticMap();
  }

  void _tryInitializeStaticMap() {
    if (!_mapReady || _staticMapInitialized) return;

    final controller = context.read<OrderDetailController>();
    final order = controller.order;
    if (order == null) return;

    final restLoc = order.restaurant.location;
    final delLoc = order.deliveryLocation;

    if (restLoc.latitude == null ||
        restLoc.longitude == null ||
        delLoc.latitude == null ||
        delLoc.longitude == null) return;

    _shopLatLng = LatLng(restLoc.latitude!, restLoc.longitude!);
    _deliveryLatLng = LatLng(delLoc.latitude!, delLoc.longitude!);

    _shopMarker = Marker(
        markerId: const MarkerId('shop'),
      position: _shopLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow:
          InfoWindow(title: order.restaurant.name, snippet: "Restaurant"),
      );

    _customerMarker = Marker(
      markerId: const MarkerId('customer'),
      position: _deliveryLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow:
          InfoWindow(title: order.customer.name, snippet: "Delivery Address"),
    );

      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 4,
        points: [_shopLatLng!, _deliveryLatLng!],
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
    };

    _staticMapInitialized = true;

    final points = [
      _shopLatLng!,
      _deliveryLatLng!,
      if (_agentLatLng != null) _agentLatLng!,
    ];

    if (_mapController != null && points.length >= 2) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(_bounds(points), 100),
      );
    }

    setState(() {});
  }

  LatLngBounds _bounds(List<LatLng> pts) {
    double? x0, x1, y0, y1;

    for (final p in pts) {
      if (x0 == null) {
        x0 = x1 = p.latitude;
        y0 = y1 = p.longitude;
      } else {
        if (p.latitude > x1!) x1 = p.latitude;
        if (p.latitude < x0) x0 = p.latitude;
        if (p.longitude > y1!) y1 = p.longitude;
        if (p.longitude < y0!) y0 = p.longitude;
      }
    }

    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  Set<Marker> _markers() {
    final list = <Marker>{};
    if (_shopMarker != null) list.add(_shopMarker!);
    if (_customerMarker != null) list.add(_customerMarker!);
    if (_agentMarker != null) list.add(_agentMarker!);
    return list;
  }

  // ---------------- UI ---------------- //

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderDetailController>(
          builder: (context, controller, _) {
        // If still loading / not ready
        if (controller.order == null) {
          return Center(child: CircularProgressIndicator());
            }

        final order = controller.order!;
        // Only update stage from backend if not currently sliding
        if (!_isSliding) {
          final backendStage = mapBackendStatus(
            order.agentDeliveryStatus.toLowerCase(),
          );

          // Never allow stage to go backwards (backend can lag for a moment).
          if (_stageRank(backendStage) > _stageRank(_stage)) {
            _stage = backendStage;
          }

          // Sticky pickup complete flag
          if (_isPickupStageOrBeyond(_stage)) {
            _pickupCompleted = true;
          }

          // If pickup is completed, automatically switch UI to Delivery section
          // so the delivery slider becomes visible (and pickup bar doesn't show there).
          if (_pickupCompleted && _activeSection == ActiveSection.pickup) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _activeSection = ActiveSection.delivery;
              });
            });
          }
            }
        // Reset response flag if order no longer shows accept/reject
        if (order.showAcceptReject != true && _hasRespondedToOrder) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasRespondedToOrder = false;
              });
            }
          });
        }
        _tryInitializeStaticMap();

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
                children: [
              Positioned.fill(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                    target: LatLng(order.restaurant.location.latitude ?? 0.0,
                        order.restaurant.location.longitude ?? 0.0),
                        zoom: 12,
                      ),
                  onMapCreated: _onMapCreated,
                  markers: _markers(),
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                    ),
                  ),

              /// Draggable Bottom Sheet
              DraggableScrollableSheet(
                initialChildSize: 0.35,
                minChildSize: 0.18,
                maxChildSize: 0.9,
                snap: true,
                snapSizes: const [0.18, 0.35, 0.6, 0.9],
                builder: (context, scroll) {
                  return DefaultTextStyle(
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      color: Colors.white,
                    ),
                    child: _detailsSheet(order, scroll),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- Details Sheet ---------------- //

  Widget _detailsSheet(dynamic order, ScrollController scroll) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
      child: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
                        child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                    const SizedBox(height: 12),

                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                                ),
                      ),
                    ),

                    // Pickup section (for scroll target)
                    GestureDetector(
                      onTap: () async {
                        setState(() => _activeSection = ActiveSection.pickup);
                        await _scrollToSection(_pickupSectionKey);
                      },
                      child: Container(
                        key: _pickupSectionKey,
                        child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors.white),
                                      const SizedBox(width: 8),
                              Text('${_formatTime(order.createdAt)} - Pickup'),
                            ],
                          ),
                          _statusPill(_pickupTimelineStatus(order)),
                                    ],
                                  ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Arrival section (for scroll target)
                    Container(
                      key: _arrivalSectionKey,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.white),
                              const SizedBox(width: 12),
                              Text(order.customer.name),
                            ],
                          ),
                          _circleBtn(Icons.phone, Colors.green, () {
                            _makePhoneCall(order.customer.phone);
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Delivery section (for scroll target)
                    GestureDetector(
                      onTap: () async {
                        if (!_isPickupCompletedBySlider()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Complete Pickup first to unlock Delivery",
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _activeSection = ActiveSection.delivery);
                        await _scrollToSection(_deliverySectionKey);
                      },
                      child: Container(
                        key: _deliverySectionKey,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "${order.deliveryAddress.city}, ${order.deliveryAddress.state}, India",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _statusPill(_deliveryTimelineStatus(order)),
                            const SizedBox(width: 10),
                            _circleBtn(
                              _isPickupCompletedBySlider()
                                  ? Icons.navigation
                                  : Icons.lock,
                              _isPickupCompletedBySlider()
                                  ? Colors.blue
                                  : Colors.grey,
                              () {
                                if (!_isPickupCompletedBySlider()) return;
                                _openNavigation(
                                  order.deliveryLocation.latitude,
                                  order.deliveryLocation.longitude,
                                );
                              },
                              enabled: _isPickupCompletedBySlider(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                  children: [
                        const Icon(Icons.receipt, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          "ORDER ID #${order.id.substring(order.id.length - 8)}",
                    ),
                  ],
                ),

                    const SizedBox(height: 25),

                    _expandTile("TASK DETAILS", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsPage(order: order),
                        ),
                      );
                    }),

                    const SizedBox(height: 15),

                    _lockedTile(
                      "SPECIAL INSTRUCTIONS",
                      order.instructions.isEmpty ? "-" : order.instructions,
                    ),

                    const SizedBox(height: 15),

                    _lockedTile("DISCOUNT", "₹ 0.00"),

                    const SizedBox(height: 15),

                    _lockedTile(
                      "SUBTOTAL",
                      "₹ ${order.collectAmount.toStringAsFixed(2)}",
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Pinned action area at bottom (Accept/Reject + Slider)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAcceptRejectButtons(order),
                  if (order.showAcceptReject != true) ...[
                    if (_activeSection == ActiveSection.pickup) ...[
                      // Pickup: show pickup slider only until pickup is completed.
                      if (_isPickupCompletedBySlider()) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.45),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Pickup Completed",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        _buildSlideButton(),
                      ],
                    ] else ...[
                      // Delivery: show delivery slider only after pickup is completed.
                      if (!_isPickupCompletedBySlider())
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.35),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock,
                                  color: Colors.white54, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Complete Pickup to start Delivery",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _buildSlideButton(),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Accept / Reject ---------------- //

Widget _buildAcceptRejectButtons(dynamic order) {
  final responseController = context.watch<AgentOrderResponseController>();

  final bool shouldShowButtons = order.showAcceptReject == true && !_hasRespondedToOrder;
  final bool isLoading = responseController.isLoading;

  if (!shouldShowButtons) {
    return const SizedBox.shrink();
  }

              return Column(
                children: [
      Row(
        children: [
          // ---------- ACCEPT ----------
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : () async {
                await _respondToOrder("accept");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
              child: responseController.loadingIndex == 0
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Pickup Order",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),

          const SizedBox(width: 12),

          // ---------- REJECT ----------
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : () async {
                await _respondToOrder("reject");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
              child: responseController.loadingIndex == 1
                  ? 
                  const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
          ),
                    )
                  : const Text("Reject",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );
}





  Future<void> _respondToOrder(String action) async {
    final agentController = context.read<AgentOrderResponseController>();
    
    // Prevent multiple taps
    if (agentController.isLoading || _hasRespondedToOrder) return;
    
    // Hide buttons immediately
    setState(() {
      _hasRespondedToOrder = true;
    });
    
    await agentController.respond(widget.orderId, action);

    if (!mounted) return;

    if (agentController.error != null) {
      // Show buttons again on error
      setState(() {
        _hasRespondedToOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed: ${agentController.error}"),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${action == "accept" ? "accepted" : "rejected"}'),
          backgroundColor: Colors.green,
        ),
      );

      // If rejected, navigate back
      if (action == "reject") {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Refresh order details for accept
      await context
          .read<OrderDetailController>()
          .loadOrderDetails(widget.orderId);

      // Reset flag after a delay to allow order to update
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _hasRespondedToOrder = false;
          });
        }
      });
    }
  }

  Widget _buildSlideButton() {
  final controller = context.watch<OrderDetailController>();
  final bool isLoading = controller.isSlideLoading;

  final bool isCompleted = _stage == DeliveryStage.completed;

  if (isCompleted) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Completed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
            ),
            ),
          ],
        ),
      ),
    );
  }

  final Color trackColor = _getStageColor();
  final String label = isLoading ? "Updating…" : _getStageLabel();

  return SizedBox(
    height: 56,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double knobSize = 52;
        final double maxKnobX = width - knobSize;
        final double clampedProgress = _slideProgress.clamp(0.0, 1.0);
        final double knobX = maxKnobX * clampedProgress;

        return GestureDetector(
          onHorizontalDragUpdate: isLoading
              ? null
              : (details) {
                  final dx = details.localPosition.dx;
                  double p = dx / maxKnobX;
                  if (p < 0) p = 0;
                  if (p > 1) p = 1;
                  setState(() {
                    _slideProgress = p;
                  });
                },
          onHorizontalDragEnd: isLoading
              ? null
              : (_) {
                  if (_slideProgress > 0.8) {
                    _onSlideCompleted();
                  } else {
                    setState(() {
                      _slideProgress = 0;
                    });
                  }
                },
          child: Stack(
        children: [
              // Track
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isLoading
                      ? Colors.grey.withOpacity(0.2)
                      : trackColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLoading
                        ? Colors.grey
                        : trackColor.withOpacity(0.6),
            ),
          ),
                alignment: Alignment.center,
            child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Knob
              Positioned(
                left: knobX.clamp(0.0, maxKnobX),
                top: 2,
                bottom: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: knobSize,
                  decoration: BoxDecoration(
                    color: isLoading ? Colors.grey : trackColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: trackColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.double_arrow,
                          color: Colors.white,
              ),
            ),
          ),
        ],
          ),
        );
      },
      ),
    );
  }


  /// 🔥 IMPORTANT PART: handle exception + drag back on failure
  void _onSlideCompleted() async {
  // Prevent multiple slide operations
  if (_isSliding) return;
  
  final DeliveryStage previousStage = _stage;
  DeliveryStage newStage;

  switch (_stage) {
    case DeliveryStage.awaitingStart:
    case DeliveryStage.notStarted:
      newStage = DeliveryStage.goingToPickup;
      break;

    case DeliveryStage.goingToPickup:
      newStage = DeliveryStage.atPickup;
      break;

    case DeliveryStage.atPickup:
      newStage = DeliveryStage.goingToCustomer;
      break;

    case DeliveryStage.goingToCustomer:
      newStage = DeliveryStage.outForDelivery;
      break;

    case DeliveryStage.outForDelivery:
      newStage = DeliveryStage.reachedCustomer;
      break;

    case DeliveryStage.reachedCustomer:
      newStage = DeliveryStage.completed;
      break;

    case DeliveryStage.completed:
      return;
  }

  // Set sliding flag to prevent stage from being overwritten
  setState(() {
    _isSliding = true;
    _stage = newStage;
    _slideProgress = 0;
  });

  if (!_statusAPIMap.containsKey(newStage)) {
    setState(() {
      _isSliding = false;
    });
    return;
  }

  final status = _statusAPIMap[newStage]!;
  final controller = context.read<OrderDetailController>();

  final success = await controller.updateOrderStatus(status);

  if (!mounted) return;

  if (success) {
    // Sticky pickup complete: once we reach picked_up stage, keep it.
    if (_isPickupStageOrBeyond(newStage)) {
      _pickupCompleted = true;
    }

    // Refresh orders list
    context.read<OrderController>().fetchOrders();
    
    // Allow stage to be updated from backend after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isSliding = false;
        });
      }
    });

    // ✅ CLOSE BOTTOM SHEET WHEN COMPLETED
    if (newStage == DeliveryStage.completed) {
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        Navigator.of(context).pop(true); // <-- THIS IS THE KEY LINE
      }
    }
  } else {
    // Rollback UI on failure
    setState(() {
      _isSliding = false;
      _stage = previousStage;
      _slideProgress = 0;
    });

      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          controller.errorMessage ?? "Something went wrong",
        ),
      ),
      );
  }
}

  

  String _getStageLabel() {
    switch (_stage) {
      case DeliveryStage.awaitingStart:
      case DeliveryStage.notStarted:
        return "Slide to start";

      case DeliveryStage.goingToPickup:
        return "Slide when reached restaurant";

      case DeliveryStage.atPickup:
        return "Slide when picked up";

      case DeliveryStage.goingToCustomer:
        return "Slide to start delivery";

      case DeliveryStage.outForDelivery:
        return "Slide when reached customer";

      case DeliveryStage.reachedCustomer:
        return "Slide to complete";

      case DeliveryStage.completed:
        return "Completed";
    }
  }

  Color _getStageColor() {
    switch (_stage) {
      case DeliveryStage.awaitingStart:
      case DeliveryStage.notStarted:
        return Colors.orange; // Start journey

      case DeliveryStage.goingToPickup:
        return Colors.blue; // Going to restaurant

      case DeliveryStage.atPickup:
        return Colors.purple; // Reached restaurant

      case DeliveryStage.goingToCustomer:
        return Colors.teal; // Picked up → heading to customer

      case DeliveryStage.outForDelivery:
        return Colors.indigo; // Out for delivery

      case DeliveryStage.reachedCustomer:
        return Colors.deepOrange; // Reached customer

      case DeliveryStage.completed:
        return Colors.green; // Delivered
    }
  }

  // ---------------- Helpers ---------------- //

  Widget _circleBtn(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _expandTile(String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            const Icon(Icons.chevron_right, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _lockedTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              const Icon(Icons.lock, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: Colors.grey[400])),
        ],
                ),
    );
  }

  String _formatTime(DateTime date) {
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, "0");
    final period = hour >= 12 ? "pm" : "am";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return "$hour:$minute $period";
  }

  // ---------------- PICKUP/DELIVERY TIMELINE STATUS ---------------- //
  bool _isPickupCompletedBySlider() {
    // Use sticky bool so UI doesn't flicker if backend sends older state briefly.
    return _pickupCompleted || _isPickupStageOrBeyond(_stage);
  }

  String _pickupTimelineStatus(dynamic order) {
    // Drive pickup/delivery sections from the rider flow, not restaurant status.
    // Backend `agentDeliveryStatus` values (seen in this file):
    // awaiting_start, start_journey_to_restaurant, reached_restaurant,
    // picked_up, out_for_delivery, reached_customer, delivered
    final agentStatus =
        (order.agentDeliveryStatus ?? '').toString().toLowerCase();

    // Pickup is completed only once the rider has picked up the order.
    if (agentStatus == 'picked_up' ||
        agentStatus == 'out_for_delivery' ||
        agentStatus == 'reached_customer' ||
        agentStatus == 'delivered') {
      return "Completed";
    }

    // Rider has started / reached restaurant → pickup in progress
    if (agentStatus == 'start_journey_to_restaurant' ||
        agentStatus == 'reached_restaurant') {
      return "In Progress";
    }

    return "Pending";
  }

  String _deliveryTimelineStatus(dynamic order) {
    final agentStatus =
        (order.agentDeliveryStatus ?? '').toString().toLowerCase();

    if (agentStatus == 'delivered') {
      return "Completed";
    }

    // Delivery starts only after pickup is completed (picked_up onwards)
    if (agentStatus == 'picked_up' ||
        agentStatus == 'out_for_delivery' ||
        agentStatus == 'reached_customer') {
      return "In Progress";
    }

    return "Pending";
  }

  Widget _statusPill(String status) {
    final Color bg;
    final Color fg;

    switch (status) {
      case "Completed":
        bg = Colors.green.withOpacity(0.2);
        fg = Colors.greenAccent;
        break;
      case "In Progress":
        bg = Colors.purple.withOpacity(0.2);
        fg = Colors.purpleAccent;
        break;
      default:
        bg = Colors.grey.withOpacity(0.2);
        fg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ---------------- LAUNCHERS ---------------- //

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openNavigation(double? lat, double? lng) async {
    if (lat == null || lng == null) return;

    final Uri url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

// Extension
extension OrderDetailsBottomSheetExtension on BuildContext {
  Future<void> showOrderBottomSheet(
      String orderId, VoidCallback onStart) async {
    return showModalBottomSheet(
      context: this,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderDetailsBottomSheet(
        orderId: orderId,
      ),
    );
  }
}
