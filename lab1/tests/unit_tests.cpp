#include <gtest/gtest.h>
#include "../math_operations.h"

TEST(AdditionTest, PositiveNumbers) {
    EXPECT_EQ(add(2, 3), 5);
    EXPECT_EQ(add(10, 20), 30);
}

TEST(AdditionTest, NegativeNumbers) {
    EXPECT_EQ(add(-2, -3), -5);
    EXPECT_EQ(add(-10, -20), -30);
}

TEST(AdditionTest, MixedNumbers) {
    EXPECT_EQ(add(-2, 3), 1);
    EXPECT_EQ(add(10, -20), -10);
}

TEST(AdditionTest, ZeroHandling) {
    EXPECT_EQ(add(0, 0), 0);
    EXPECT_EQ(add(5, 0), 5);
    EXPECT_EQ(add(0, 5), 5);
}

int main(int argc, char **argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}