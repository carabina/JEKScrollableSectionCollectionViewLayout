//
//  JEKScrollableSectionCollectionViewLayout.m
//  Example Project
//
//  Created by Joel Ekström on 2018-07-19.
//  Copyright © 2018 Joel Ekström. All rights reserved.
//

#import "JEKScrollableSectionCollectionViewLayout.h"

static NSString * const JEKScrollableCollectionViewLayoutScrollViewKind = @"JEKScrollableCollectionViewLayoutScrollViewKind";

@class JEKScrollableSectionInfo;

@interface JEKScrollableSectionDecorationViewLayoutAttributes : UICollectionViewLayoutAttributes
@property (nonatomic, strong) JEKScrollableSectionInfo *section;
@property (nonatomic, assign) BOOL showsHorizontalScrollIndicator;
@end

@interface JEKScrollableSectionInfo : NSObject
@property (nonatomic, assign) CGPoint offset;
@property (nonatomic, assign) CGFloat interItemSpacing;
@property (nonatomic, assign) UIEdgeInsets insets;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, assign) CGFloat collectionViewWidth;
@property (nonatomic, strong) NSMutableArray<NSValue *> *itemSizes;
@property (nonatomic, assign) CGSize headerSize;
@property (nonatomic, assign) CGSize footerSize;
- (void)prepareLayout;

@property (nonatomic, readonly) CGRect frame; // Relative frame of the section in the collection view
@property (nonatomic, readonly) CGRect bounds; // The rect containing all elements of the section (items, header, footer), starting at (0,0)
@property (nonatomic, readonly) CGRect itemFrame; // The rect containing the items but not headers and footers
@property (nonatomic, readonly) JEKScrollableSectionDecorationViewLayoutAttributes *decorationViewAttributes;
@property (nonatomic, readonly) UICollectionViewLayoutAttributes *headerViewAttributes;
@property (nonatomic, readonly) UICollectionViewLayoutAttributes *footerViewAttributes;

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesIntersectingRect:(CGRect)rect;
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndex:(NSUInteger)index;
@end

@interface JEKScrollableSectionLayoutInvalidationContext : UICollectionViewLayoutInvalidationContext
@property (nonatomic, strong) JEKScrollableSectionInfo *invalidatedSection;
@end

@interface JEKScrollableSectionCollectionViewLayout() <UIScrollViewDelegate>
@property (nonatomic, assign) CGSize contentSize;
@property (nonatomic, assign) BOOL isAdjustingBoundsToInvalidateHorizontalSection;
@property (nonatomic, strong) NSArray<JEKScrollableSectionInfo *> *sections;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *offsetCache;
@property (nonatomic, weak) id<UICollectionViewDelegateFlowLayout> delegate;
@end

@interface JEKScrollableSectionDecorationView : UICollectionReusableView <UIGestureRecognizerDelegate>
@property (nonatomic, readonly, strong) UIScrollView *scrollView;
@property (nonatomic, strong) JEKScrollableSectionInfo *section;
@end

@interface JEKScrollView : UIScrollView @end

@implementation JEKScrollableSectionCollectionViewLayout

- (instancetype)init
{
    if (self = [super init]) {
        [self configure];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self configure];
    }
    return self;
}

- (void)configure
{
    [self registerClass:JEKScrollableSectionDecorationView.class forDecorationViewOfKind:JEKScrollableCollectionViewLayoutScrollViewKind];
    self.offsetCache = [NSMutableDictionary new];
    self.showsHorizontalScrollIndicators = YES;
}

+ (Class)invalidationContextClass
{
    return JEKScrollableSectionLayoutInvalidationContext.class;
}

- (BOOL)flipsHorizontallyInOppositeLayoutDirection
{
    return YES;
}

- (void)prepareLayout
{
    [super prepareLayout];

    if (self.sections != nil) {
        return;
    }

    NSMutableArray<JEKScrollableSectionInfo *> *sections = [NSMutableArray new];
    NSInteger numberOfSections = [self.collectionView numberOfSections];
    CGFloat yOffset = 0.0;

    for (NSInteger section = 0; section < numberOfSections; ++section) {
        JEKScrollableSectionInfo *sectionInfo = [JEKScrollableSectionInfo new];
        sectionInfo.indexPath = [NSIndexPath indexPathWithIndex:section];
        sectionInfo.insets = [self sectionInsetsForSection:section];
        sectionInfo.interItemSpacing = [self interItemSpacingForSection:section];
        sectionInfo.headerSize = [self headerSizeForSection:section];
        sectionInfo.footerSize = [self footerSizeForSection:section];
        sectionInfo.collectionViewWidth = self.collectionView.frame.size.width;

        NSMutableArray<NSValue *> *itemSizes = [NSMutableArray new];
            for (NSInteger item = 0; item < [self.collectionView numberOfItemsInSection:section]; ++item) {
            CGSize itemSize = [self itemSizeForIndexPath:[sectionInfo.indexPath indexPathByAddingIndex:item]];
            [itemSizes addObject:[NSValue valueWithCGSize:itemSize]];
        }

        sectionInfo.itemSizes = itemSizes;
        [sectionInfo prepareLayout];

        sectionInfo.offset = CGPointMake(self.offsetCache[@(section)].floatValue, yOffset);
        yOffset += CGRectGetHeight(sectionInfo.frame);
        [sections addObject:sectionInfo];
    }

    self.sections = [sections copy];
    self.contentSize = CGSizeMake(self.collectionView.frame.size.width, yOffset);
}

- (void)invalidateLayoutWithContext:(JEKScrollableSectionLayoutInvalidationContext *)context
{
    [super invalidateLayoutWithContext:context];

    if (context.invalidateEverything) {
        self.sections = nil;
        return;
    }

    if (context.invalidatedSection) {
        CGPoint offset = context.invalidatedSection.offset;
        offset.x = self.offsetCache[@([self.sections indexOfObject:context.invalidatedSection])].floatValue;
        context.invalidatedSection.offset = offset;
    }

    self.contentSize = CGSizeMake(self.collectionView.frame.size.width, self.contentSize.height);
}

- (CGSize)collectionViewContentSize
{
    return self.contentSize;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.sections[indexPath.section] layoutAttributesForItemAtIndex:indexPath.item];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    JEKScrollableSectionInfo *section = self.sections[indexPath.section];
    return elementKind == UICollectionElementKindSectionHeader ? section.headerViewAttributes : section.footerViewAttributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
    if (elementKind == JEKScrollableCollectionViewLayoutScrollViewKind) {
        JEKScrollableSectionDecorationViewLayoutAttributes *attributes = self.sections[indexPath.section].decorationViewAttributes;
        attributes.showsHorizontalScrollIndicator = self.showsHorizontalScrollIndicators;
        return attributes;
    }
    return nil;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *visibleAttributes = [NSMutableArray new];
    BOOL anyVisibleSectionFound = NO;
    for (JEKScrollableSectionInfo *section in self.sections) {
        NSArray *intersectingAttributes = [section layoutAttributesIntersectingRect:rect];
        if (intersectingAttributes.count > 0) {
            anyVisibleSectionFound = YES;
            [visibleAttributes addObjectsFromArray:intersectingAttributes];
        }

        // Optimization: If we have seen previously intersecting items but the current one
        // doesn't intersect, we can break to avoid extra work since they are enumerated
        // in visible order.
        // TODO: Find the first visible section/items using binary search instead of enumerating
        // from first index. Right now, if the visible bounds are on section 3000, then 2999 sections will be enumerated
        // but not visible.
        else if (anyVisibleSectionFound) { break; }
    }
    return visibleAttributes;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    NSUInteger section = scrollView.tag;
    self.offsetCache[@(section)] = @(-scrollView.contentOffset.x);

    JEKScrollableSectionLayoutInvalidationContext *invalidationContext = [JEKScrollableSectionLayoutInvalidationContext new];
    invalidationContext.invalidatedSection = self.sections[section];
    [self invalidateLayoutWithContext:invalidationContext];
    [self adjustBoundsToInvalidateVisibleItemIndexPaths];
}

// NOTE: UICollectionView will only ever dequeue new cells if its bounds
// change, regardless if all layout attributes are updated within invalidateLayoutWithContext.
// Therefore a hack is required to make this layout work. After updating the frames in
// invalidateLayoutWithContext: above, slightly change the bounds to make sure that the
// collectionView queries for cells that may have entered the visible area.
- (void)adjustBoundsToInvalidateVisibleItemIndexPaths
{
    _isAdjustingBoundsToInvalidateHorizontalSection = YES;
    CGRect bounds = self.collectionView.bounds;
    bounds.origin.x = bounds.origin.x == 0.0 ? -0.1 : 0.0;
    [self.collectionView setBounds:bounds];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    if (_isAdjustingBoundsToInvalidateHorizontalSection) {
        _isAdjustingBoundsToInvalidateHorizontalSection = NO;
        return YES;
    } else if (newBounds.size.width != self.contentSize.width) {
        return YES;
    }
    return NO;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds
{
    UICollectionViewLayoutInvalidationContext *context = [super invalidationContextForBoundsChange:newBounds];
    if (newBounds.size.width != self.collectionViewContentSize.width) {
        for (JEKScrollableSectionInfo *section in self.sections) {
            NSIndexPath *sectionIndexPath = [NSIndexPath indexPathWithIndex:[self.sections indexOfObject:section]];
            [context invalidateDecorationElementsOfKind:JEKScrollableCollectionViewLayoutScrollViewKind atIndexPaths:@[sectionIndexPath]];
            [context invalidateSupplementaryElementsOfKind:UICollectionElementKindSectionHeader atIndexPaths:@[sectionIndexPath]];
            [context invalidateSupplementaryElementsOfKind:UICollectionElementKindSectionFooter atIndexPaths:@[sectionIndexPath]];
        }
    }
    return context;
}

#pragma mark - Measurements

- (CGFloat)interItemSpacingForSection:(NSUInteger)section
{
    return [self.delegate respondsToSelector:@selector(collectionView:layout:minimumInteritemSpacingForSectionAtIndex:)] ? [self.delegate collectionView:self.collectionView layout:self minimumInteritemSpacingForSectionAtIndex:section] : self.minimumInteritemSpacing;
}

- (UIEdgeInsets)sectionInsetsForSection:(NSUInteger)section
{
    return [self.delegate respondsToSelector:@selector(collectionView:layout:insetForSectionAtIndex:)] ? [self.delegate collectionView:self.collectionView layout:self insetForSectionAtIndex:section] : self.sectionInset;
}

- (CGSize)headerSizeForSection:(NSUInteger)section
{
    return [self.delegate respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)] ? [self.delegate collectionView:self.collectionView layout:self referenceSizeForHeaderInSection:section] : self.headerReferenceSize;
}

- (CGSize)footerSizeForSection:(NSUInteger)section
{
    return [self.delegate respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)] ? [self.delegate collectionView:self.collectionView layout:self referenceSizeForFooterInSection:section] : self.footerReferenceSize;
}

- (CGSize)itemSizeForIndexPath:(NSIndexPath *)indexPath
{
    return [self.delegate respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)] ? [self.delegate collectionView:self.collectionView layout:self sizeForItemAtIndexPath:indexPath] : self.itemSize;
}

- (id<UICollectionViewDelegateFlowLayout>)delegate
{
    id delegate = self.collectionView.delegate;
    return [delegate conformsToProtocol:@protocol(UICollectionViewDelegateFlowLayout)] ? delegate : nil;
}

@end

@implementation JEKScrollableSectionDecorationView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _scrollView = [[JEKScrollView alloc] initWithFrame:self.bounds];
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _scrollView.showsHorizontalScrollIndicator = YES;
        _scrollView.alwaysBounceVertical = NO;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.directionalLockEnabled = YES;
        [self addSubview:_scrollView];
        self.userInteractionEnabled = NO;
        [self addObserver:self forKeyPath:@"section.bounds" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"section.bounds"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    // When items are inserted/deleted, we need to update the scroll view content size, so listen to
    // bounds changes within the section
    if ([keyPath isEqualToString:@"section.bounds"]) {
        self.scrollView.contentSize = self.section.itemFrame.size;
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)applyLayoutAttributes:(JEKScrollableSectionDecorationViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    self.section = layoutAttributes.section;
    self.scrollView.tag = layoutAttributes.indexPath.section;
    self.scrollView.showsHorizontalScrollIndicator = layoutAttributes.showsHorizontalScrollIndicator;
    [self.scrollView setContentOffset:CGPointMake(-layoutAttributes.section.offset.x, 0.0) animated:NO];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (self.superview) {
        UICollectionView *collectionView = (UICollectionView *)self.superview;
        self.scrollView.delegate = (JEKScrollableSectionCollectionViewLayout *)collectionView.collectionViewLayout;
        [collectionView addGestureRecognizer:self.scrollView.panGestureRecognizer];
        _scrollView.transform = [self shouldFlipLayoutDirection] ? CGAffineTransformMakeScale(-1.0, 1.0) : CGAffineTransformIdentity;
    } else {
        self.scrollView.delegate = nil;
        [self.scrollView.panGestureRecognizer.view removeGestureRecognizer:self.scrollView.panGestureRecognizer];
    }
}

- (BOOL)shouldFlipLayoutDirection
{
    if (@available(iOS 11.0, *)) {
        return self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    }
    return NO;
}

@end

@implementation JEKScrollView

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(nonnull UITouch *)touch
{
    JEKScrollableSectionDecorationView *decorationView = (JEKScrollableSectionDecorationView *)self.superview;
    if (CGRectContainsPoint(decorationView.frame, [touch locationInView:decorationView.superview])) {
        return YES;
    } else {
        // NOTE: This is a bugfix. When the collection view receives a touch it will pause the deceleration
        // of any scroll view that is currently scrolling - however the scroll view is never informed that it
        // is stopped, which makes its scrolling indicator stay visible forever. We make sure that the scroll view
        // knows that it is stopped by forcing a stop whenever anything else receives a touch.
        [self setContentOffset:self.contentOffset animated:NO];
        return NO;
    }
}

@end

@implementation JEKScrollableSectionDecorationViewLayoutAttributes

- (id)copyWithZone:(NSZone *)zone
{
    JEKScrollableSectionDecorationViewLayoutAttributes *copy = [super copyWithZone:zone];
    copy.section = self.section;
    copy.showsHorizontalScrollIndicator = self.showsHorizontalScrollIndicator;
    return copy;
}

@end

@interface JEKScrollableSectionInfo()
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, strong) NSArray<NSValue *> *itemFrames;
@end

@implementation JEKScrollableSectionInfo

- (void)prepareLayout
{
    CGRect bounds = CGRectZero;
    bounds.size.width = self.insets.left;
    NSMutableArray<NSValue *> *itemFrames = [NSMutableArray new];
    for (NSUInteger item = 0; item < self.itemSizes.count; ++item) {
        CGSize size = [self.itemSizes[item] CGSizeValue];
        CGRect frame;
        frame.size = size;
        frame.origin.x = CGRectGetMaxX(bounds) + (item == 0 ? 0.0 : self.interItemSpacing);
        frame.origin.y = self.insets.top + self.headerSize.height;
        bounds = CGRectUnion(bounds, frame);
        [itemFrames addObject:[NSValue valueWithCGRect:frame]];
    }
    bounds.size.width += self.insets.right;
    bounds.size.height += self.footerSize.height + self.insets.bottom;
    self.bounds = bounds;
    self.itemFrames = [itemFrames copy];
}

- (CGRect)frame
{
    return CGRectOffset(self.bounds, self.offset.x, self.offset.y);
}

- (CGRect)itemFrame
{
    return UIEdgeInsetsInsetRect(self.frame, UIEdgeInsetsMake(self.headerSize.height + self.insets.top, 0.0, self.footerSize.height + self.insets.bottom, 0.0));
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndex:(NSUInteger)index
{
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[self.indexPath indexPathByAddingIndex:index]];
    attributes.frame = CGRectOffset(self.itemFrames[index].CGRectValue, self.offset.x, self.offset.y);
    return attributes;
}

- (UICollectionViewLayoutAttributes *)headerViewAttributes
{
    if (CGSizeEqualToSize(self.headerSize, CGSizeZero)) {
        return nil;
    }

    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader withIndexPath:self.indexPath];
    attributes.frame = CGRectMake(0.0, self.offset.y, self.collectionViewWidth, self.headerSize.height);
    return attributes;
}

- (UICollectionViewLayoutAttributes *)footerViewAttributes
{
    if (CGSizeEqualToSize(self.footerSize, CGSizeZero)) {
        return nil;
    }

    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter withIndexPath:self.indexPath];
    CGRect sectionFrame = self.frame;
    attributes.frame = CGRectMake(0.0, CGRectGetMaxY(sectionFrame) - self.footerSize.height, self.collectionViewWidth, self.footerSize.height);
    return attributes;
}

- (JEKScrollableSectionDecorationViewLayoutAttributes *)decorationViewAttributes
{
    JEKScrollableSectionDecorationViewLayoutAttributes *attributes = [JEKScrollableSectionDecorationViewLayoutAttributes layoutAttributesForDecorationViewOfKind:JEKScrollableCollectionViewLayoutScrollViewKind withIndexPath:self.indexPath];
    CGRect frame = [self itemFrame];
    attributes.section = self;

    frame.origin.x = 0.0;
    frame.size.width = self.collectionViewWidth;

    attributes.frame = frame;
    attributes.zIndex = 1;
    return attributes;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesIntersectingRect:(CGRect)rect
{
    NSMutableArray *intersectingAttributes = [NSMutableArray new];
    if (self.headerViewAttributes && CGRectIntersectsRect(self.headerViewAttributes.frame, rect)) {
        [intersectingAttributes addObject:self.headerViewAttributes];
    }

    if (self.footerViewAttributes && CGRectIntersectsRect(self.footerViewAttributes.frame, rect)) {
        [intersectingAttributes addObject:self.footerViewAttributes];
    }

    if (CGRectIntersectsRect(self.decorationViewAttributes.frame, rect)) {
        [intersectingAttributes addObject:self.decorationViewAttributes];
        BOOL visibleItemsFound = NO;
        for (NSInteger i = 0; i < self.itemFrames.count; ++i) {
            CGRect frame = CGRectOffset(self.itemFrames[i].CGRectValue, self.offset.x, self.offset.y);
            if (CGRectIntersectsRect(frame, rect)) {
                visibleItemsFound = YES;
                [intersectingAttributes addObject:[self layoutAttributesForItemAtIndex:i]];
            }

            // Optimization: If we have seen previously intersecting items but the current one
            // doesn't intersect, we can break to avoid extra work since they are enumerated
            // in visible order.
            else if (visibleItemsFound) { break; }
        }
    }
    return intersectingAttributes;
}

@end

@implementation JEKScrollableSectionLayoutInvalidationContext @end
