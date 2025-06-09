import 'package:flutter/material.dart';

class SearchAutocomplete extends StatefulWidget {
  final Function(String) onLocationSelected;
  final String? hintText;
  final double? maxDropdownHeight;

  const SearchAutocomplete({
    super.key,
    required this.onLocationSelected,
    this.hintText = "Search for your destination",
    this.maxDropdownHeight = 200,
  });

  @override
  State<SearchAutocomplete> createState() => _SearchAutocompleteState();
}

class _SearchAutocompleteState extends State<SearchAutocomplete>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  bool _showDropdown = false;
  List<String> _filteredSuggestions = [];
  
  // Sample Cairo locations for Phase 1
  static const List<String> _sampleLocations = [
    'Tahrir Square',
    'Cairo Festival City',
    'New Administrative Capital',
    'Zamalek',
    'Maadi',
    'Nasr City',
    'Heliopolis',
    'Downtown Cairo',
    'Giza Pyramids',
    'Cairo Airport',
    'Khan El Khalili',
    'Islamic Cairo',
    'Coptic Cairo',
    'City Stars Mall',
    'Mall of Arabia',
    'American University in Cairo',
    'Cairo University',
    'Al-Azhar Mosque',
    'Salah El Din Citadel',
    'Cairo Opera House',
    'Egyptian Museum',
    'Gezira Club',
    'Sporting Club',
    'New Cairo',
    'Fifth Settlement',
    'Sheraton',
    'Dokki',
    'Mohandessin',
    'Agouza',
    'Garden City',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _filteredSuggestions = List.from(_sampleLocations);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showDropdownWithAnimation();
      } else {
        // Close dropdown when search field loses focus
        _hideDropdownWithAnimation();
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSuggestions = List.from(_sampleLocations);
      } else {
        _filteredSuggestions = _sampleLocations
            .where((location) => location.toLowerCase().contains(query))
            .toList();
      }
    });

    if (_filteredSuggestions.isNotEmpty && !_showDropdown) {
      _showDropdownWithAnimation();
    } else if (_filteredSuggestions.isEmpty && _showDropdown) {
      _hideDropdownWithAnimation();
    }
  }

  void _showDropdownWithAnimation() {
    if (!_showDropdown) {
      setState(() {
        _showDropdown = true;
      });
      _animationController.forward();
    }
  }

  void _hideDropdownWithAnimation() {
    if (_showDropdown) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showDropdown = false;
          });
        }
      });
    }
  }

  void _onSuggestionTapped(String suggestion) {
    setState(() {
      _searchController.text = suggestion;
    });
    _hideDropdownWithAnimation();
    _focusNode.unfocus();
    widget.onLocationSelected(suggestion);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _filteredSuggestions = List.from(_sampleLocations);
    });
    _showDropdownWithAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search TextField
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            boxShadow: _showDropdown
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: const TextStyle(
              color: Colors.grey,           // This makes the typed text grey
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: _clearSearch,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onTap: _showDropdownWithAnimation,
          ),
        ),

        // Dropdown Suggestions
        if (_showDropdown)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.scale(
                scaleY: _animation.value,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: _animation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: BoxConstraints(
                maxHeight: widget.maxDropdownHeight!,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _filteredSuggestions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No locations found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filteredSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _filteredSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _getLocationIcon(suggestion),
                            color: const Color(0xFF38B6FF),
                            size: 20,
                          ),
                          title: Text(
                            suggestion,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _getLocationSubtitle(suggestion),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          onTap: () => _onSuggestionTapped(suggestion),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        );
                      },
                    ),
            ),
          ),
      ],
    );
  }

  IconData _getLocationIcon(String location) {
    if (location.contains('Mall') || location.contains('City Stars')) {
      return Icons.local_mall;
    } else if (location.contains('Airport')) {
      return Icons.flight;
    } else if (location.contains('University') || location.contains('AUC')) {
      return Icons.school;
    } else if (location.contains('Museum')) {
      return Icons.museum;
    } else if (location.contains('Mosque') || location.contains('Islamic') || location.contains('Coptic')) {
      return Icons.place_outlined;
    } else if (location.contains('Club')) {
      return Icons.sports_tennis;
    } else if (location.contains('Opera')) {
      return Icons.theater_comedy;
    } else if (location.contains('Pyramids')) {
      return Icons.landscape;
    } else {
      return Icons.location_on;
    }
  }

  String _getLocationSubtitle(String location) {
    Map<String, String> locationDetails = {
      'Tahrir Square': 'Downtown Cairo',
      'Cairo Festival City': 'New Cairo, Shopping Mall',
      'New Administrative Capital': 'Government District',
      'Zamalek': 'Gezira Island',
      'Maadi': 'South Cairo',
      'Nasr City': 'East Cairo',
      'Heliopolis': 'Northeast Cairo',
      'Downtown Cairo': 'City Center',
      'Giza Pyramids': 'Giza, Tourist Attraction',
      'Cairo Airport': 'Heliopolis, International Airport',
      'Khan El Khalili': 'Islamic Cairo, Bazaar',
      'Islamic Cairo': 'Historic District',
      'Coptic Cairo': 'Old Cairo, Historic District',
      'City Stars Mall': 'Nasr City, Shopping Mall',
      'Mall of Arabia': 'Giza, Shopping Mall',
      'American University in Cairo': 'New Cairo Campus',
      'Cairo University': 'Giza, Main Campus',
      'Al-Azhar Mosque': 'Islamic Cairo',
      'Salah El Din Citadel': 'Islamic Cairo, Historic Site',
      'Cairo Opera House': 'Zamalek, Cultural Center',
      'Egyptian Museum': 'Tahrir Square, Museum',
      'Gezira Club': 'Zamalek, Sports Club',
      'Sporting Club': 'Mohandessin, Sports Club',
      'New Cairo': 'East Cairo, Residential',
      'Fifth Settlement': 'New Cairo, Residential',
      'Sheraton': 'Heliopolis, Hotel District',
      'Dokki': 'Giza, Residential',
      'Mohandessin': 'Giza, Commercial District',
      'Agouza': 'Giza, Residential',
      'Garden City': 'Downtown, Residential',
    };
    
    return locationDetails[location] ?? 'Cairo, Egypt';
  }
}